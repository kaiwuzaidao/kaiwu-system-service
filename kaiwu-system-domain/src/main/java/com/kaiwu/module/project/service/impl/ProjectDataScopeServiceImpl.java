package com.kaiwu.module.project.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.operation.model.FieldChange;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.convert.DataScopeReducer;
import com.kaiwu.module.project.convert.DataScopeReducer.Reduction;
import com.kaiwu.module.project.convert.DataScopeReducer.RoleScope;
import com.kaiwu.module.project.convert.DataScopeSnapshotAssembler;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.entity.DataScopeResourceRow;
import com.kaiwu.module.project.entity.DataScopeRoleScopeRow;
import com.kaiwu.module.project.entity.DataScopeUserDepartmentRow;
import com.kaiwu.module.project.model.DataScopeType;
import com.kaiwu.module.project.repository.ProjectDataScopeRepository;
import com.kaiwu.module.project.repository.ProjectDataScopeRepository.NewConfig;
import com.kaiwu.module.project.repository.ProjectDataScopeRepository.StoredConfig;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.vo.DataScopeView;
import com.kaiwu.module.project.vo.ProjectDataResourceView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.starter.KaiwuContext;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 项目数据范围用例的实现。快照路径只读、不开事务；保存路径锁定角色行后整体替换。
 */
@Service
public class ProjectDataScopeServiceImpl implements ProjectDataScopeService {

    private static final Logger LOG = LoggerFactory.getLogger(ProjectDataScopeServiceImpl.class);
    private static final String PROJECT_ADMIN = "project-admin";
    private static final int MAX_CUSTOM_DEPARTMENTS = 128;
    private static final Pattern DEPT_ID = Pattern.compile("^[0-9]{1,19}$");
    private static final Comparator<String> NUMERIC =
            Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder());
    private static final String INVALID_KEY = "api.project.dataScopeInvalid";

    private final ProjectDataScopeRepository repository;
    private final ProjectRepository projectRepository;
    private final AuditService auditService;

    /** 注入数据范围仓储、项目仓储（角色查询与行锁）和审计。 */
    public ProjectDataScopeServiceImpl(
            ProjectDataScopeRepository repository, ProjectRepository projectRepository, AuditService auditService) {
        this.repository = repository;
        this.projectRepository = projectRepository;
        this.auditService = auditService;
    }

    @Override
    public Optional<DataScopeView> snapshot(String projectId, String userId) {
        List<DataScopeResourceRow> resources = repository.findEnabledResources(projectId);
        if (resources.isEmpty()) {
            return Optional.empty();
        }
        List<DataScopeRoleScopeRow> roleRows = repository.findMemberRoleScopes(projectId, userId);
        boolean projectAdmin = roleRows.stream().anyMatch(row -> row.builtIn() && PROJECT_ADMIN.equals(row.roleCode()));
        List<DataScopeUserDepartmentRow> userDepartments = repository.findUserDepartments(userId);
        Set<String> userDepts = new LinkedHashSet<>();
        userDepartments.forEach(row -> userDepts.add(row.departmentId()));

        Map<String, Reduction> byResource = new TreeMap<>();
        if (projectAdmin) {
            resources.forEach(resource -> byResource.put(resource.resourceCode(), Reduction.everything()));
        } else {
            Map<String, Set<DataScopeType>> allowedByResource = new HashMap<>();
            resources.forEach(
                    resource -> allowedByResource.put(resource.resourceCode(), parseAllowed(resource.allowedScopes())));
            List<DataScopeRoleScopeRow> usable = roleRows.stream()
                    .filter(row -> row.scopeId() != null)
                    .filter(row -> allowedByResource.containsKey(row.resourceCode()))
                    .toList();
            Map<String, Set<String>> customDepts = repository.findScopeDepts(
                    usable.stream().map(DataScopeRoleScopeRow::scopeId).toList());
            boolean needsTree = usable.stream()
                    .anyMatch(row -> DataScopeType.DEPT_AND_CHILD.name().equals(row.scopeType())
                            || Boolean.TRUE.equals(row.includeChild()));
            Map<String, List<String>> children = needsTree ? repository.findChildrenByParent() : Map.of();
            for (DataScopeResourceRow resource : resources) {
                List<RoleScope> scopes = new ArrayList<>();
                for (DataScopeRoleScopeRow row : usable) {
                    if (!resource.resourceCode().equals(row.resourceCode())) {
                        continue;
                    }
                    // 配置的类型已不在资源允许范围内、或值无法识别时，按仅本人处理，只会变窄。
                    DataScopeType type = DataScopeType.parse(row.scopeType()).orElse(null);
                    if (type == null
                            || !allowedByResource.get(resource.resourceCode()).contains(type)) {
                        continue;
                    }
                    scopes.add(new RoleScope(
                            type,
                            Boolean.TRUE.equals(row.includeChild()),
                            customDepts.getOrDefault(row.scopeId(), Set.of())));
                }
                byResource.put(resource.resourceCode(), DataScopeReducer.reduce(scopes, userDepts, children));
            }
        }

        DataScopeView view = DataScopeSnapshotAssembler.assemble(primaryDepartment(userDepartments), byResource);
        int size = DataScopeSnapshotAssembler.sizeBytes(view);
        if (size > DataScopeSnapshotAssembler.MAX_BYTES) {
            // 日志只记大小，不记部门 ID。
            LOG.warn("数据范围超过上限 projectId={} userId={} bytes={}", projectId, userId, size);
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "数据范围过大，请联系管理员调整",
                    "api.project.dataScopeTooLarge",
                    Map.of("reason", "DATA_SCOPE_TOO_LARGE", "limitBytes", DataScopeSnapshotAssembler.MAX_BYTES));
        }
        return Optional.of(view);
    }

    @Override
    public ProjectRoleDataScopeView roleScopes(String projectId, String roleId) {
        ProjectRoleView role = requireRole(projectRepository.findRole(projectId, roleId));
        return viewOf(projectId, role);
    }

    @Override
    @Transactional
    public ProjectRoleDataScopeView saveRoleScopes(
            String projectId,
            String roleId,
            ProjectRoleDataScopeRequest request,
            KaiwuContext actor,
            RequestMetadata metadata) {
        ProjectRoleView role = requireRole(projectRepository.findRoleForUpdate(projectId, roleId));
        if (role.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        }
        Map<String, DataScopeResourceRow> resources = new HashMap<>();
        repository.findEnabledResources(projectId).forEach(row -> resources.put(row.resourceCode(), row));
        List<NewConfig> next = validate(request, resources);

        Map<String, StoredConfig> before = repository.findRoleConfigs(roleId);
        List<FieldChange> changes = diff(before, next);
        if (changes.isEmpty()) {
            return viewOf(projectId, role);
        }
        repository.replaceRoleConfigs(projectId, roleId, next, LongIdGenerator::nextId);
        auditService.recordOperationWithDiff(
                actor,
                "project",
                "SAVE_PROJECT_ROLE_DATA_SCOPE",
                "/api/projects/" + projectId + "/roles/" + roleId + "/data-scopes",
                "ProjectRole",
                roleId,
                changes,
                metadata);
        return viewOf(projectId, role);
    }

    @Override
    public List<ProjectDataResourceView> resources(String projectId) {
        return repository.findAllResources(projectId).stream()
                .map(row -> new ProjectDataResourceView(
                        row.resourceCode(),
                        row.resourceName(),
                        parseAllowed(row.allowedScopes()).stream()
                                .map(DataScopeType::name)
                                .toList(),
                        row.status()))
                .toList();
    }

    @Override
    @Transactional
    public void saveResource(String projectId, String code, String name, List<String> allowedScopes) {
        repository.saveResource(projectId, code, name, String.join(",", allowedScopes), LongIdGenerator::nextId);
    }

    @Override
    public long configsOutside(String projectId, String code, List<String> allowedScopes) {
        return repository.countConfigsOutside(projectId, code, allowedScopes);
    }

    @Override
    public Map<String, String> departmentIdsByCode(Collection<String> codes) {
        return repository.departmentIdsByCode(codes);
    }

    @Override
    public Map<String, String> departmentCodesById(Collection<String> ids) {
        return repository.departmentCodesById(ids);
    }

    /** 逐项校验请求并整理成待写入的配置；SELF 等价于未配置，不落库。 */
    private List<NewConfig> validate(ProjectRoleDataScopeRequest request, Map<String, DataScopeResourceRow> resources) {
        Set<String> seen = new HashSet<>();
        List<NewConfig> result = new ArrayList<>();
        for (ProjectRoleDataScopeRequest.Item item : request.items()) {
            if (!seen.add(item.resourceCode())) {
                throw invalid("资源重复：" + item.resourceCode());
            }
            DataScopeResourceRow resource = resources.get(item.resourceCode());
            if (resource == null) {
                throw invalid("资源不存在或未启用：" + item.resourceCode());
            }
            DataScopeType type = DataScopeType.parse(item.scope()).orElseThrow(() -> invalid("范围类型无效：" + item.scope()));
            if (!parseAllowed(resource.allowedScopes()).contains(type)) {
                throw invalid("资源 " + item.resourceCode() + " 不允许使用范围 " + type);
            }
            List<String> depts = item.deptIds() == null ? List.of() : item.deptIds();
            if (type != DataScopeType.CUSTOM_DEPT) {
                if (!depts.isEmpty() || item.includeChild()) {
                    throw invalid("只有 CUSTOM_DEPT 可以指定部门或包含下级");
                }
                if (type != DataScopeType.SELF) {
                    result.add(new NewConfig(item.resourceCode(), type.name(), false, List.of()));
                }
                continue;
            }
            result.add(new NewConfig(item.resourceCode(), type.name(), item.includeChild(), checkedDepartments(depts)));
        }
        result.sort(Comparator.comparing(NewConfig::resourceCode));
        return result;
    }

    /** 校验勾选的部门：非空、格式正确、不重复、不超上限、全部存在；返回按数值升序的列表。 */
    private List<String> checkedDepartments(List<String> depts) {
        if (depts.isEmpty()) {
            throw invalid("CUSTOM_DEPT 至少选择一个部门");
        }
        if (depts.size() > MAX_CUSTOM_DEPARTMENTS) {
            throw invalid("指定部门最多 " + MAX_CUSTOM_DEPARTMENTS + " 个");
        }
        Set<String> unique = new LinkedHashSet<>();
        for (String dept : depts) {
            if (dept == null || !DEPT_ID.matcher(dept).matches() || !unique.add(dept)) {
                throw invalid("部门 ID 无效或重复：" + dept);
            }
        }
        Set<String> existing = repository.findExistingDepartmentIds(unique);
        if (!existing.containsAll(unique)) {
            throw invalid("部分部门不存在");
        }
        return unique.stream().sorted(NUMERIC).toList();
    }

    /** 逐资源比较前后配置，只返回有变化的资源。 */
    private static List<FieldChange> diff(Map<String, StoredConfig> before, List<NewConfig> next) {
        Map<String, String> after = new LinkedHashMap<>();
        next.forEach(config -> after.put(
                config.resourceCode(), describe(config.scopeType(), config.includeChild(), config.deptIds())));
        Set<String> codes = new java.util.TreeSet<>(before.keySet());
        codes.addAll(after.keySet());
        List<FieldChange> changes = new ArrayList<>();
        for (String code : codes) {
            StoredConfig old = before.get(code);
            String oldText = old == null
                    ? "SELF"
                    : describe(
                            old.scopeType(),
                            old.includeChild(),
                            old.deptIds().stream().sorted(NUMERIC).toList());
            String newText = after.getOrDefault(code, "SELF");
            if (!oldText.equals(newText)) {
                changes.add(new FieldChange(code, oldText, newText));
            }
        }
        return changes;
    }

    /** 审计里的可读描述，例如 {@code CUSTOM_DEPT+CHILD[1,2]}。 */
    private static String describe(String scopeType, boolean includeChild, List<String> deptIds) {
        if (!DataScopeType.CUSTOM_DEPT.name().equals(scopeType)) {
            return scopeType;
        }
        return scopeType + (includeChild ? "+CHILD" : "") + deptIds;
    }

    /** 组装管理视图：内置角色整体只读，其余角色逐资源给出有效配置。 */
    private ProjectRoleDataScopeView viewOf(String projectId, ProjectRoleView role) {
        List<DataScopeResourceRow> resources = repository.findEnabledResources(projectId);
        boolean admin = role.builtIn() && PROJECT_ADMIN.equals(role.roleCode());
        Map<String, StoredConfig> configs = admin ? Map.of() : repository.findRoleConfigs(role.id());
        List<ProjectRoleDataScopeView.Item> items = new ArrayList<>();
        for (DataScopeResourceRow resource : resources) {
            List<String> allowed = parseAllowed(resource.allowedScopes()).stream()
                    .map(DataScopeType::name)
                    .sorted()
                    .toList();
            if (admin) {
                items.add(new ProjectRoleDataScopeView.Item(
                        resource.resourceCode(),
                        resource.resourceName(),
                        allowed,
                        DataScopeType.ALL.name(),
                        false,
                        false,
                        List.of()));
                continue;
            }
            StoredConfig stored = configs.get(resource.resourceCode());
            DataScopeType type = stored == null
                    ? null
                    : DataScopeType.parse(stored.scopeType()).orElse(null);
            if (type == null || !parseAllowed(resource.allowedScopes()).contains(type)) {
                items.add(new ProjectRoleDataScopeView.Item(
                        resource.resourceCode(),
                        resource.resourceName(),
                        allowed,
                        DataScopeType.SELF.name(),
                        false,
                        false,
                        List.of()));
                continue;
            }
            items.add(new ProjectRoleDataScopeView.Item(
                    resource.resourceCode(),
                    resource.resourceName(),
                    allowed,
                    type.name(),
                    true,
                    stored.includeChild(),
                    stored.deptIds().stream().sorted(NUMERIC).toList()));
        }
        return new ProjectRoleDataScopeView(role.id(), role.roleCode(), admin, items);
    }

    /** 主部门：优先取标记为主部门的记录，数值最小者；都没有标记时取全部所属部门中数值最小者。 */
    private static String primaryDepartment(List<DataScopeUserDepartmentRow> rows) {
        return rows.stream()
                .filter(DataScopeUserDepartmentRow::primary)
                .map(DataScopeUserDepartmentRow::departmentId)
                .min(NUMERIC)
                .or(() -> rows.stream()
                        .map(DataScopeUserDepartmentRow::departmentId)
                        .min(NUMERIC))
                .orElse(null);
    }

    /** 解析逗号分隔的允许范围，未知值直接丢弃；结果恒含 {@code SELF}，与清单校验保持一致。 */
    private static Set<DataScopeType> parseAllowed(String text) {
        Set<DataScopeType> allowed = java.util.EnumSet.of(DataScopeType.SELF);
        Arrays.stream(text.split(","))
                .map(String::trim)
                .map(DataScopeType::parse)
                .flatMap(Optional::stream)
                .forEach(allowed::add);
        return allowed;
    }

    private static ProjectRoleView requireRole(Optional<ProjectRoleView> role) {
        return role.orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
    }

    private static ApiException invalid(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, message, INVALID_KEY);
    }
}
