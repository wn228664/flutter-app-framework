// Android 应用模块：组合 Flutter 与原生壳；当前 release 沿用 debug 签名，仅能作为本地验证配置。

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter 插件必须在 Android 与 Kotlin 插件后应用，确保它能读取正确的应用扩展。
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Kotlin 与资源的命名空间，需与 Android 源码包名保持一致。
    namespace = "dev.framework.flutter_app_framework"
    // 编译 API 级别跟随当前 Flutter SDK 的工具链约定。
    compileSdk = flutter.compileSdkVersion
    // 锁定项目使用的 NDK，避免本机默认版本漂移。
    ndkVersion = "27.0.12077973"

    // Java 字节码及 Kotlin JVM 目标均为 11，保持原生依赖一致。
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Android 安装标识；派生新应用时应与签名及发布渠道共同确认。
        applicationId = "dev.framework.flutter_app_framework"
        // 最低 Android API 为 23；目标 API 及版本号由 Flutter/pubspec 驱动，不在两处重复维护。
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 本地验证使用 debug 签名；分发前由新项目配置自己的正式签名。
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Flutter 源目录为目标项目根，不引用业务源仓。
flutter {
    source = "../.."
}
