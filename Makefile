# FLUTTER：项目 SDK 定位入口，统一透传本机 PATH、FLUTTER_BIN 或 local.properties 中的 SDK。
FLUTTER := ./tool/flutterw

.PHONY: run verify build-android build-ios
# 在调用方选择的设备启动；多设备时由 Flutter 要求明确目标。
run:
	$(FLUTTER) run

# 使用已解析依赖完成静态检查和组件/单元回归，不在校验期间更新依赖。
verify:
	$(FLUTTER) analyze --no-pub
	$(FLUTTER) test --no-pub

# Android 本地 Debug 包，只证明构建成功，不代表正式签名发布。
build-android:
	$(FLUTTER) build apk --debug --no-pub

# iOS 设备目标的无签名 Debug 构建；安装到真实设备仍需合法签名。
build-ios:
	$(FLUTTER) build ios --debug --no-codesign --no-pub
