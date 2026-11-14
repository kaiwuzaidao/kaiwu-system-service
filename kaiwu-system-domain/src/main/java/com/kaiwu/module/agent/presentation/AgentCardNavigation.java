package com.kaiwu.module.agent.presentation;

import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.ParamType;
import com.kaiwu.module.agent.vo.AgentCardView;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Builds navigation only from reviewed declarations and already projected rows.
 * Commands are conveniences, not grants: submission is validated and authorized again.
 */
public final class AgentCardNavigation {
    private AgentCardNavigation() {}

    public static AgentCardView.Navigation build(
            Capability source,
            Map<String, Object> params,
            List<Map<String, Object>> rows,
            boolean truncated,
            List<Capability> visible) {
        var view = source.outputView();
        if (view == null || !source.canSkipConfirmation()) return null;
        Integer page = null;
        AgentCardView.Command previous = null;
        AgentCardView.Command next = null;
        if (view.pagination() != null && source.inputForm() != null && !truncated) {
            var paging = view.pagination();
            var pageSpec = source.paramsSchema().get(paging.pageParam());
            var sizeSpec = source.paramsSchema().get(paging.sizeParam());
            page = ((Number) params.getOrDefault(paging.pageParam(), pageSpec.defaultValue())).intValue();
            int size = ((Number) params.getOrDefault(paging.sizeParam(), sizeSpec.defaultValue())).intValue();
            if (page > 1) previous = pageCommand(source, params, paging.pageParam(), page - 1);
            // A full page may be the last page. No fake total: next can legitimately return empty.
            if (rows.size() == size && page < pageSpec.max())
                next = pageCommand(source, params, paging.pageParam(), page + 1);
        }
        var details = new ArrayList<AgentCardView.RowCommand>();
        if (view.detail() != null) {
            var binding = view.detail();
            var target = visible.stream()
                    .filter(cap -> cap.code().equals(binding.capabilityCode())
                            && cap.projectCode().equals(source.projectCode())
                            && cap.canSkipConfirmation()
                            && cap.inputForm() != null)
                    .findFirst();
            if (target.isPresent()) {
                var schema = target.get().paramsSchema();
                var spec = schema.get(binding.param());
                boolean complete = schema.entrySet().stream()
                        .noneMatch(entry -> entry.getValue().required()
                                && entry.getValue().defaultValue() == null
                                && !entry.getKey().equals(binding.param()));
                if (spec != null && spec.type() == ParamType.STRING && complete) {
                    for (int index = 0; index < rows.size(); index++) {
                        Object value = rows.get(index).get(binding.rowField());
                        if (!(value instanceof String text)
                                || text.isBlank()
                                || (spec.maxLength() != null && text.length() > spec.maxLength())) continue;
                        details.add(new AgentCardView.RowCommand(
                                index,
                                new AgentCardView.Command(
                                        binding.label(), binding.capabilityCode(), Map.of(binding.param(), text))));
                    }
                }
            }
        }
        if (page == null && details.isEmpty()) return null;
        return new AgentCardView.Navigation(page, previous, next, List.copyOf(details));
    }

    private static AgentCardView.Command pageCommand(
            Capability source, Map<String, Object> params, String pageParam, int page) {
        var values = new LinkedHashMap<String, Object>(params);
        values.put(pageParam, page);
        return new AgentCardView.Command(source.outputView().title(), source.code(), values);
    }
}
