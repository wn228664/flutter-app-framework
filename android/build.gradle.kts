// Android 根构建配置：统一依赖源、输出目录和 clean 范围；不定义应用业务行为。

// 给根工程和所有子工程提供 Android 依赖仓库。
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// newBuildDir：统一迁移到 Flutter 项目根 build/ 的构建目录，避免各模块分散产物。
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// 为每个子工程按自身 project.name 划分输出，避免构建产物冲突。
subprojects {
    // newSubprojectBuildDir：当前子工程在共享 build/ 下的独立输出位置。
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 子工程求值前确保 app 已配置，沿用 Flutter Gradle 的项目求值顺序。
subprojects {
    project.evaluationDependsOn(":app")
}

// clean 回调只删除本目标工程的构建目录，不清理其他仓库或全局 SDK。
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
