package com.kaiwu.module.metadata.vo;

import java.util.List;

public record EffectiveDictView(String code, String name, String description, List<DictItemView> items) {}
