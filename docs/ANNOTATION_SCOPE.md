# 注释范围与验证边界

`lib/` 的 26 个 Dart 文件和 `test/` 的 8 个测试文件，按实际声明说明类型、构造函数、字段、局部变量、参数、回调及捕获异常。参数说明与所属函数、构造函数、字段或回调放在一起，逐个点名；匿名忽略参数分别说明来源。公开接口说明默认值、单位、失败传播、身份代次、异步资源和调用方责任。声明清单用于定位遗漏，不能代替语义审查。

`tool/flutterw`、Makefile、Android Gradle/Kotlin/清单与主题资源、iOS Podfile/Swift/桥接声明、公开 plist 及 xcconfig、pubspec 和分析选项也在手写注释范围。配置值与依赖版本沿用原工程。CocoaPods 在读取新增 Podfile 注释后只更新 `PODFILE CHECKSUM`；Pods 版本和 spec 校验值不变。

二进制格式例外为 25 个 PNG 和 1 个可变字体；字体的 OFL 许可证保留原文。2 个资源 JSON 与 2 个锁文件保持工具格式，不插入逐字段注释。Flutter `.metadata`、Xcode 工程/工作区/scheme 元数据、2 个 storyboard 和 `ios/Flutter/AppFrameworkInfo.plist` 由对应工具维护，职责在此说明，不修改其内部生成标识。storyboard 仅承载 Flutter 宿主与中性启动背景，AppFrameworkInfo 是 Flutter 嵌入框架元数据。依赖、Pods、生成注册器、构建缓存和打包产物不作人工注释。

语义对比使用 Dart 解析器的 AST 和非注释 token。格式器可能增删调用、列表和参数表的可选尾逗号；这种差异单独列出，并核对 AST 结构。其他原生源码、配置和 XML 也需比较去注释内容或解析结果，不能以“只是注释”为由跳过。

组件测试使用隔离传输、存储和 WebView 平台替身；Android 构建、模拟器运行、iOS 编译及真机插件行为分别验收。没有后端也能启动，但真实 API、设备安全存储、网页交互和发布签名需要对应环境验证。空的 Xcode 原生测试模板不作为功能覆盖证据。
