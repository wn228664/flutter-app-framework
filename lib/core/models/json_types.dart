// JSON 对象边界：统一使用 String 键和可空 Object 值，具体字段转换由 json_readers 执行。

/// 接口 JSON 对象的类型别名；值仍须经过严格读取器验证，不能把强转当作字段校验。
typedef JsonMap = Map<String, Object?>;
