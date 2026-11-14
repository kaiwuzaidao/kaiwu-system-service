package com.kaiwu.module.agent.planning;

import com.kaiwu.module.agent.protocol.Capability;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * 对明确点名受控资源的查询，在接触模型前给出统一拒绝。
 *
 * <p>这里只覆盖高置信度的资源名称；含糊的问题仍交给裁剪后的能力目录规划。
 * 映射不对外返回能力码，也不说明资源是否存在、未上线或无权访问。</p>
 *
 * <p>只收录平台自身的能力。业务项目的能力由按权限裁剪后的目录兜底：无权能力根本不进入
 * 规划，平台核心不内置任何业务项目的资源名称。</p>
 */
public final class ExplicitReadIntentGuard {
    private static final Pattern QUERY = Pattern.compile("查看|查询|列出|显示|统计|获取|查找|搜索|看看|有哪些|多少");
    private static final Pattern DETAIL_SUFFIX = Pattern.compile(
            "^\\s*(?:(?:编号|[Ii][Dd]|#|[:：])?\\s*[1-9][0-9]{0,18}\\s*(?:号|条|项|个)?\\s*的?\\s*)?(?:详情|详细信息)");

    private static final List<Intent> INTENTS = List.of(
            new Intent("system.audit.operation.list", List.of("操作日志", "操作审计")),
            new Intent("system.audit.login.list", List.of("登录日志", "登录审计")),
            new Intent("system.session.list", List.of("在线会话", "会话列表")),
            new Intent("system.project.member.list", List.of("项目成员")),
            new Intent("system.project.role.list", List.of("项目角色")),
            new Intent("system.project.menu.list", List.of("项目菜单")),
            new Intent("system.scheduler.execution.list", List.of("定时任务执行记录", "调度执行记录")),
            new Intent("system.scheduler.list", List.of("定时任务列表", "调度任务列表")),
            new Intent("system.user.list", List.of("平台用户列表")),
            new Intent("system.department.list", List.of("部门列表")),
            new Intent("system.config.list", List.of("平台参数配置")),
            new Intent("system.config.detail", List.of("参数配置详情")),
            new Intent("system.dict-type.list", List.of("平台字典列表")),
            new Intent("system.dict-item.list", List.of("平台字典项")),
            new Intent("system.project.list", List.of("项目列表")),
            new Intent("system.generation.list", List.of("项目生成记录", "代码生成记录")),
            new Intent("system.generation.detail", List.of("生成任务详情")),
            new Intent("system.ai-provider.status", List.of("AI服务配置状态", "AI 服务配置状态", "大模型配置状态")),
            new Intent("system.i18n-message.list", List.of("国际化资源列表", "翻译资源列表")),
            new Intent("system.i18n-locale.list", List.of("语言覆盖状态", "可选语言列表")));

    private ExplicitReadIntentGuard() {}

    public static boolean denied(String question, List<Capability> visible) {
        if (question == null || !QUERY.matcher(question).find()) return false;
        Set<String> visibleCodes = visible.stream().map(Capability::code).collect(java.util.stream.Collectors.toSet());
        List<Intent> matched =
                INTENTS.stream().filter(intent -> matches(intent, question)).toList();
        return matched.stream()
                .anyMatch(intent ->
                        !visibleCodes.contains(intent.code()) && !coveredByNamedDetail(intent, matched, question));
    }

    private static boolean coveredByNamedDetail(Intent intent, List<Intent> matched, String question) {
        if (!intent.code().endsWith(".list") || explicitlyNamesList(intent, question)) return false;
        String detailCode = intent.code().substring(0, intent.code().length() - ".list".length()) + ".detail";
        return matched.stream().anyMatch(other -> other.code().equals(detailCode));
    }

    private static boolean explicitlyNamesList(Intent intent, String question) {
        return intent.terms().stream()
                .anyMatch(term -> term.endsWith("列表")
                        ? question.contains(term)
                        : question.contains(term + "列表")
                                || question.contains(term + "清单")
                                || question.contains("列出" + term));
    }

    private static boolean matches(Intent intent, String question) {
        for (String term : intent.terms()) {
            if (question.contains(term)) return true;
            if (!intent.code().endsWith(".detail") || !term.endsWith("详情")) continue;
            String resource = term.substring(0, term.length() - "详情".length());
            for (int at = question.indexOf(resource);
                    at >= 0;
                    at = question.indexOf(resource, at + resource.length())) {
                if (DETAIL_SUFFIX
                        .matcher(question.substring(at + resource.length()))
                        .lookingAt()) return true;
            }
        }
        return false;
    }

    private record Intent(String code, List<String> terms) {}
}
