// Android 页面入口：原生生命周期交给 FlutterActivity，应用 UI 和路由在 Dart 层维护。

package dev.framework.flutter_app_framework

import io.flutter.embedding.android.FlutterActivity

/** Flutter 默认 Activity 宿主；无自定义 MethodChannel、权限请求或业务初始化。 */
class MainActivity : FlutterActivity()
