# APP 通用封装

仅 Android / iOS。调用方向：页面 → Provider / Controller → 网络与存储；共享组件只消费参数与回调。没有小说、支付、客服、推送协议或生产服务依赖。

## 核心层

| 入口 | 契约与失败处理 |
| --- | --- |
| `core/config/app_config.dart` | 读取 APP_TITLE / API_BASE_URL 编译参数并校验；没有 API 地址也可启动，仅发请求时拒绝。 |
| `core/network/api_client.dart` | Dio 请求、相对路径约束、超时、CancelToken、会话代次与 401 隔离。`request<T>(path, decode: ..., authenticated: ...)` 将原始响应交给 decode，不假设业务成功码，不重试写操作。 |
| `core/network/api_exception.dart` | 类型化错误，保留可展示 message、code、statusCode，不在日志泄漏 token 或响应正文。 |
| `core/storage/token_store.dart` | 写入串行化，读取等待已发起的修改；write / clear 发起即增加 revision。存储失败继续向调用方抛出，read 不回退到旧凭证；后续成功写入可恢复。 |
| `core/storage/secure_token_storage.dart` | 默认系统安全存储。Android 使用 Keystore 保护的加密偏好，iOS 使用本应用 Keychain；`TokenStorage` 可注入测试或新平台后端。 |
| `core/state/action_lock_controller.dart` | `run<T>(key, action)` 按动作键防重复；重复或 owner 已销毁时返回 null，动作错误透传，finally 释放锁。调用方负责取消、后端幂等及页面离开后停止消费结果。 |
| `core/state/theme_controller.dart` | system / light / dark，SharedPreferences 仅保存非敏感主题。串行保存后更新 UI，失败不阻断后续选择，销毁后不更新状态。 |
| `core/models/` | JSON 标量与列表检查、ThemeConfig、PageData。整数拒绝小数和非有限值，Map 键必须为字符串；分页 total>=0、page>=1、pageSize>=1。PageData 默认读取 list / total / pageNum（或 page）/ pageSize，新接口可另写适配器。 |

```dart
final cancel = CancelToken();
final payload = await api.request<Map<String, Object?>>(
  '/items',
  cancelToken: cancel,
  decode: (value) => Map<String, Object?>.from(value as Map),
);
// 在 owner 销毁或被新请求替代时 cancel.cancel()；不要在 UI 中直接持有凭证。
```

ApiClient 拥有传入 Dio 的配置与生命周期，close 会关闭它；不要跨不同会话 owner 共享该实例。authenticated=false 不读取凭证、不执行 401 清理。认证请求在读取凭证前后及响应交付前核对 revision，旧成功不会调用 decode，旧 401 不清理新会话。错误码包括 API_NOT_CONFIGURED / INVALID_PATH / SESSION_CHANGED / CANCELLED / HTTP_ERROR。

安全存储键为中性的 framework_session_token，没有复制原应用的业务键或历史迁移。Android minSdk=23（Android 6），关闭备份以避免将加密数据恢复到缺少原 Keystore 密钥的设备。读取/写入失败不降级到明文；调用方应展示失败并允许重试。主题继续使用普通偏好，凭证不使用它。

## 共享组件

| 组件 | 使用与 owner 责任 |
| --- | --- |
| `AsyncValueView<T>` | Riverpod AsyncValue 的 loading / error / data / empty 分支，可注入 isEmpty 和 errorBuilder，onRetry 交给调用方。 |
| `EmptyState` / `ErrorState` | 空态、类型化错误消息、重试入口；窄屏、大字号与纵向内容使用自身滚动，颜色跟随主题。 |
| `AppLoadingIndicator` | compact / 普通尺寸和语义标签，供页面与分页复用。 |
| `PaginationScrollListener` | 只响应当前竖向容器 depth=0 的位置变化，同帧合并 near-end 事件，停用条件更新或销毁使旧回调失效。onLoadMore 必须同步更新 isLoading，异步请求可再使用动作锁。 |
| `PaginationFooter` | loading 优先于旧 error；retry / idle / end 可配文案与颜色。淡出中的旧重试按钮不再接收交互，长 endLabel 保留语义全文。 |
| `NetworkStatusOverlay` | 根据设备连接类型显示覆盖层；保留 child 状态，不通过换 key 重建页面。离线→在线触发 onRefresh，手动刷新覆盖整个 Future 的防重周期，失败显示提示并允许重试。 |
| `UserAvatar` | HTTP(S) 缓存图片或 JPEG/PNG Base64 Data URL，非法地址、解码失败和网络失败统一回退主题色默认头像；提供 semanticLabel。 |
| `showTopMessage` | 同 messenger 只保留最新提示，旧计时器不能关闭新提示；duration<=0 常驻，动作后关闭，正文限制高度并在自身区域滚动。 |
| `AppWebView` | HTTP(S) 页面、加载进度、主文档失败/重试，默认禁用 JavaScript、仅初始同源导航，allowedHosts 显式扩展站点；不带业务 Bridge 或凭证注入。 |

```dart
await ref.read(actionLockProvider.notifier).run('reload', () async {
  await reloadData();
});

NetworkStatusOverlay(
  onRefresh: reloadData,
  child: const ContentPage(),
);
```

连接类型不证明互联网或 API 可达。NetworkStatusOverlay 的初次检查、连接流与刷新都有代次隔离；平台检查异常时保留内容，不误判为断网。调用方在 Future 中完成真正的数据刷新，并自行管理请求取消。

WebView 的 url / javascriptEnabled / allowedHosts 变化会使用新 controller，旧事件不再更新页面。allowedHosts 更新传入新的 Set，遵守 Flutter 配置不可变约定；同源包含 scheme 和 port，白名单按 host 匹配并允许 HTTP(S)，请按新项目实际需求控制。禁止 file / javascript 等协议与 userInfo 地址。组件需在有限高度中使用；设备权限、下载、外链打开和专用 Bridge 按新应用契约另行接入。

## 应用壳与扩展

- `app/providers.dart` 负责配置、偏好、TokenStore、ApiClient 注入和关闭；测试可覆盖 provider。
- `StatefulShellRoute.indexedStack` 保留首页/外观设置的独立导航状态；新增通用路由在 `app/router.dart` 注册。
- Material 3 亮/暗主题、NotoSansSC 字体和 OFL 许可证保留；顶部消息使用自带深色高对比配色。
- Android / iOS 标识中性且独立，正式发布由新项目配置自己的图标、标识和签名。默认首页不访问后端。
- 新应用的上传/相机/文件选择如需新增，应明确平台权限和接口契约；本框架没有保留原业务上传流程或虚构上传接口。

## 依赖与验证

使用 Flutter 3.32.8 / Dart 3.8.1。`flutter_secure_storage` 固定 9.2.4，与当前 Android SDK/Gradle 工具链兼容；锁文件新增它的联邦插件依赖，原已存在包版本保持不变。WebView 测试显式声明已有 2.14.0 平台接口作为 dev dependency，使用官方测试边界，不访问真实网站。

`make verify`：静态分析无问题、28 项测试通过。覆盖请求/旧会话、动作锁、存储失败恢复、主题顺序、网络竞态与刷新、分页、窄屏/横屏大字号、顶部消息、头像、WebView 配置与事件隔离。Android Debug APK 构建通过。

2026-11-04 再次验证：分析零问题、28 项测试及 Android Debug 构建通过；API 35 ARM64 模拟器安装并启动本轮 APK，检查首页、设置、浅色选择、进程重启后外观保留和顶部消息，未发现 AndroidRuntime/Flutter 错误日志。这是模拟器关键路径验证，真实设备权限、安全存储和网页交互仍需独立确认。

iOS Pod 安装成功。`xcodebuild -showsdks` 能列出 iOS 26.0 SDK，但无签名构建的 Xcode 目的地检查仍报设备平台未安装；`simctl` 也没有可用运行时。iOS 编译和运行尚未通过，不能由 SDK 列表或 Android 成功推断。注释范围及生成文件例外见 `ANNOTATION_SCOPE.md`。
