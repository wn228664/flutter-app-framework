// Android 构建入口：组合本机 Flutter 工具与锁定插件版本，local.properties 缺失或 SDK 不可用时终止配置。

// 插件解析阶段先定位 Flutter SDK，缺失配置直接报错，避免使用未知版本构建。
pluginManagement {
    // flutterSdkPath：供 includeBuild 使用的 SDK 根路径，由下面的作用域严格读取。
    val flutterSdkPath = run {
        // properties：本机 Android 配置，只读取 flutter.sdk，不写入仓库。
        val properties = java.util.Properties()
        // use 的隐式 it 是文件输入流；作用域退出时关闭，不遗留文件句柄。
        file("local.properties").inputStream().use { properties.load(it) }
        // flutterSdkPath：属性表中的可空 SDK 路径，检查后返回外层作用域。
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Flutter 与 Android/Kotlin 插件的解析源，按声明顺序查询。
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// 锁定构建插件版本；Android 和 Kotlin 插件在 app 模块实际应用。
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// 唯一应用模块；业务扩展不在 settings 中偷偷引入其他源仓。
include(":app")
