package com.kaiwu.module.user;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.user.entity.UserEntity;
import com.kaiwu.module.user.mapper.UserMapper;
import com.kaiwu.module.user.vo.UserView;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

/**
 * 平台用户数据访问。
 *
 * <p>密码哈希由 {@link UserEntity} 的 {@code select = false} 挡在默认查询之外，
 * 因此本类不再需要手写列白名单。</p>
 */
@Repository
public class UserRepository {

    private final UserMapper mapper;

    private final Clock clock;

    public UserRepository(UserMapper mapper, Clock clock) {
        this.mapper = mapper;
        this.clock = clock;
    }

    /** 用户分页；关键字同时匹配用户名与显示名，密码哈希不在返回字段内。 */
    public PageResult<UserView> page(String keyword, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        Page<UserEntity> page = mapper.selectPage(
                Page.of(current, size),
                keywordQuery(keyword).orderByDesc(UserEntity::getCreatedAt).orderByDesc(UserEntity::getId));
        return new PageResult<>(
                current,
                size,
                page.getTotal(),
                page.getRecords().stream().map(UserRepository::toView).toList());
    }

    public boolean existsByUsername(String username) {
        return mapper.exists(new LambdaQueryWrapper<UserEntity>().eq(UserEntity::getUsername, username));
    }

    public Optional<UserView> findView(String id) {
        return Optional.ofNullable(mapper.selectById(Long.parseLong(id))).map(UserRepository::toView);
    }

    /**
     * 导出查询：必须带上限，避免全表加载进内存。
     *
     * <p>筛选条件与 {@link #page} 复用同一个 {@link #keywordQuery}，使导出结果等于列表页
     * 当前筛选结果——两处各写一份条件正是导出与列表悄悄不一致的成因。</p>
     *
     * @param keyword 用户名或显示名关键字，为空表示不筛选
     * @param limit   最大返回行数，由调用方多取一行用于判断是否超限
     */
    public List<UserView> listForExport(String keyword, int limit) {
        LambdaQueryWrapper<UserEntity> query = keywordQuery(keyword)
                .orderByAsc(UserEntity::getUsername)
                .orderByAsc(UserEntity::getId)
                // limit 由调用方传入的常量派生，不接受外部字符串，不构成注入面。
                .last("LIMIT " + limit);
        return mapper.selectList(query).stream().map(UserRepository::toView).toList();
    }

    /** 新建用户，初始状态 ENABLED 且强制首次登录改密。 */
    public void create(String id, String username, String displayName, String email, String passwordHash) {
        UserEntity entity = new UserEntity();
        entity.setId(Long.parseLong(id));
        entity.setUsername(username);
        entity.setPasswordHash(passwordHash);
        entity.setDisplayName(displayName);
        entity.setEmail(normalize(email));
        entity.setStatus("ENABLED");
        // 新建用户的初始密码由创建者设定并人工转达，首次登录必须改掉。
        entity.setMustChangePassword(true);
        LocalDateTime now = LocalDateTime.now(clock);
        entity.setCreatedAt(now);
        entity.setUpdatedAt(now);
        mapper.insert(entity);
    }

    /**
     * 编辑用户资料。
     *
     * <p>**必须用显式 {@code set()}**：邮箱允许被清空，而 MyBatis-Plus 的 {@code updateById}
     * 只把非 null 字段写进 SET——用实体更新时「清空邮箱」会静默失效，界面显示保存成功
     * 但值没变。迁移前的逐列 SET 语义必须保持。</p>
     */
    public int update(String id, String displayName, String email) {
        return mapper.update(
                null,
                new LambdaUpdateWrapper<UserEntity>()
                        .eq(UserEntity::getId, Long.parseLong(id))
                        .set(UserEntity::getDisplayName, displayName)
                        .set(UserEntity::getEmail, normalize(email))
                        .set(UserEntity::getUpdatedAt, LocalDateTime.now(clock)));
    }

    /** 启停用户。 @return 实际更新行数，0 表示用户不存在 */
    public int updateStatus(String id, String status) {
        UserEntity entity = new UserEntity();
        entity.setId(Long.parseLong(id));
        entity.setStatus(status);
        entity.setUpdatedAt(LocalDateTime.now(clock));
        return mapper.updateById(entity);
    }

    /**
     * 管理员重置他人密码：置强制改密标记，使该用户下次登录必须自行设置新密码。
     * 重置后的临时密码经由人工渠道传递，不应长期使用。
     */
    public int updatePassword(String id, String passwordHash) {
        return mapper.updatePassword(Long.parseLong(id), passwordHash);
    }

    public List<String> findOnlineSessionIds(String userId) {
        return mapper.findOnlineSessionIds(Long.parseLong(userId));
    }

    public void revokeOnlineSessions(String userId) {
        mapper.revokeOnlineSessions(Long.parseLong(userId));
    }

    /**
     * 列表与导出共用的关键字条件。
     *
     * <p>两个 LIKE 用 {@code and(...)} 包成一个嵌套条件：迁移前的
     * {@code WHERE username LIKE ? OR display_name LIKE ?} 一旦再加一个 AND 条件，
     * 就会因为优先级悄悄变成 {@code a OR (b AND c)}。包起来之后新增条件不会踩这个坑。</p>
     */
    private static LambdaQueryWrapper<UserEntity> keywordQuery(String keyword) {
        LambdaQueryWrapper<UserEntity> query = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(keyword)) {
            String trimmed = keyword.trim();
            query.and(nested ->
                    nested.like(UserEntity::getUsername, trimmed).or().like(UserEntity::getDisplayName, trimmed));
        }
        return query;
    }

    private static UserView toView(UserEntity entity) {
        return new UserView(
                String.valueOf(entity.getId()),
                entity.getUsername(),
                entity.getDisplayName(),
                entity.getEmail(),
                entity.getStatus(),
                entity.getCreatedAt(),
                entity.getUpdatedAt());
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}
