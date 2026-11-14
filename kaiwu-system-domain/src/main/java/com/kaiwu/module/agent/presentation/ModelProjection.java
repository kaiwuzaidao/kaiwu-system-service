package com.kaiwu.module.agent.presentation;

import java.util.List;
import java.util.Map;

/**
 * 送模型的投影：唯一允许流向外部 Provider 的结果形态。
 *
 * <p>刻意不做成 record——record 的规范构造器必须公开，而这里要的恰恰是
 * <b>构造入口唯一</b>。构造函数私有，只能经 {@link #copyWhitelisted} 产生，
 * 该方法按 {@code outboundFields} 逐字段复制，未列入的字段根本不会被读取。</p>
 *
 * <p>类型隔离本身只是必要条件：两种投影都由同一处代码从同一份原始结果构造，
 * 构造函数内部照样可能写错。把入口收成一个，再用约定测试锁死，才谈得上闭合
 * （ADR 0030 第 10 条）。Provider 客户端只接受本类型。</p>
 */
public final class ModelProjection {

    private final String capabilityCode;
    private final List<Map<String, Object>> rows;
    private final boolean truncated;

    private ModelProjection(String capabilityCode, List<Map<String, Object>> rows, boolean truncated) {
        this.capabilityCode = capabilityCode;
        this.rows = rows == null ? List.of() : List.copyOf(rows);
        this.truncated = truncated;
    }

    /**
     * 唯一构造入口，仅供同包的 {@link ResultProjector} 调用。
     *
     * <p>调用方必须已经完成白名单复制与脱敏——本方法不再兜底，
     * 因为兜底会给人「随便传，反正这里会过滤」的错觉。</p>
     */
    static ModelProjection copyWhitelisted(String capabilityCode, List<Map<String, Object>> rows, boolean truncated) {
        return new ModelProjection(capabilityCode, rows, truncated);
    }

    public String capabilityCode() {
        return capabilityCode;
    }

    public List<Map<String, Object>> rows() {
        return rows;
    }

    /** 是否因超出上限被截断；截断必须告知用户，不静默丢数据。 */
    public boolean truncated() {
        return truncated;
    }
}
