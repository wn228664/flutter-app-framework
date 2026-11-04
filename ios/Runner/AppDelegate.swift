// iOS 原生启动壳：不注册额外 Bridge 或业务服务，Dart 入口负责应用依赖初始化。

import Flutter
import UIKit

/// iOS 应用委托：只注册 Flutter 插件，窗口与应用生命周期沿用 FlutterAppDelegate。
@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 系统启动完成时注册插件，再将返回值交给 Flutter 默认启动处理。
  /// application：系统提供的当前 UIApplication 实例。
  /// launchOptions：可空系统启动信息，原样转交父类，不解析业务跳转。
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
