# AI伴侣App — 前端技术栈文档（Flutter）

**文档版本：** v1.0
**编写日期：** 2026年6月6日
**文档状态：** 从技术栈文档分离
**关联文档：** [技术栈文档（全栈）](AI伴侣App-技术栈文档.md)

---

## 1. 技术总览

```
┌─────────────────────────────────────────────────┐
│         Flutter 3.x + Dart 3.x                  │
│                                                  │
│  状态管理: Riverpod + riverpod_generator         │
│  路由: go_router + go_router_builder             │
│  网络: Dio + Retrofit + web_socket_channel       │
│  持久化: Drift (SQLite) + Hive + SecureStorage   │
│  UI: Material 3 + Cupertino + flutter_animate    │
│  动画: Lottie + shimmer                          │
│  图片: cached_network_image                      │
│  音频: just_audio + record                       │
│  推送: Firebase Messaging                        │
│  代码生成: freezed + json_serializable            │
└─────────────────────────────────────────────────┘
```

---

## 2. 开发环境

| 项目 | 版本/要求 | 说明 |
|------|----------|------|
| Flutter SDK | ≥ 3.24 | 最新稳定版 Channel |
| Dart SDK | ≥ 3.5 | 启用 sound null safety + 模式匹配 |
| Android minSdkVersion | 24 (Android 7.0) | 覆盖 99%+ Android 设备 |
| iOS 最低版本 | 15.0 | 支持最新系统 API |
| 包管理 | pub | Flutter/Dart 原生包管理器 |
| 代码规范 | very_good_analysis | Very Good Ventures 团队的 lint 规则集 |

---

## 3. 架构模式

采用 **分层架构 + Riverpod 状态管理**，结合 Clean Architecture 思想：

```
┌─────────────────────────────────────────────────┐
│                 Presentation 层                   │
│  Pages / Widgets / ViewModels (Notifier)         │
│  - 纯 UI 构建，无业务逻辑                          │
│  - 通过 Riverpod Provider 消费状态                │
└──────────────────┬──────────────────────────────┘
                   │ Riverpod Provider 监听
┌──────────────────▼──────────────────────────────┐
│                Application 层                    │
│  UseCases / Services                             │
│  - 编排业务逻辑                                    │
│  - 调用 Repository 获取数据                       │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│                 Domain 层                        │
│  Entities / Repository 接口 / Value Objects      │
│  - 纯 Dart 代码，无 Flutter 依赖                  │
│  - 定义核心业务模型和数据契约                       │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│                 Data 层                          │
│  Repository 实现 / DataSources / Models          │
│  - RemoteDataSource（API 调用）                   │
│  - LocalDataSource（本地持久化）                   │
│  - CacheDataSource（内存缓存）                    │
└─────────────────────────────────────────────────┘
```

---

## 4. 第三方库清单

所有库均通过 **pub** 集成，以下是各分类的最新热门选型：

### 4.1 状态管理与依赖注入

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **flutter_riverpod** | 响应式状态管理 + 依赖注入 | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | Riverpod v2.x，编译期安全，自动销毁，Flutter 团队推荐 |
| **riverpod_annotation** | Riverpod 代码生成注解 | [riverpod_annotation](https://pub.dev/packages/riverpod_annotation) | 配合 riverpod_generator 减少样板代码 |
| **riverpod_generator** | Riverpod 代码生成器 | [riverpod_generator](https://pub.dev/packages/riverpod_generator) | build_runner 自动生成 Provider 代码 |

> **为什么选 Riverpod 而不是 Bloc：** Riverpod 无需 BuildContext、编译期类型安全、样板代码更少（配合代码生成）、天然支持依赖注入。对于本项目（中等复杂度、需要大量异步数据流）Riverpod 更高效。Bloc 更适合超大型企业应用中需要严格事件溯源的场景。

### 4.2 导航路由

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **go_router** | 声明式路由管理 | [go_router](https://pub.dev/packages/go_router) | Flutter 团队官方推荐，支持深链接、重定向、ShellRoute（底部 Tab） |
| **go_router_builder** | 路由代码生成 | [go_router_builder](https://pub.dev/packages/go_router_builder) | 类型安全的路由参数，编译期检查 |

### 4.3 网络请求

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **dio** | HTTP 客户端 | [dio](https://pub.dev/packages/dio) | 支持拦截器、请求取消、FormData 上传、超时重试 |
| **retrofit** | 类型安全的 API 接口定义 | [retrofit](https://pub.dev/packages/retrofit) | 注解式 API 定义（类似 Android Retrofit），配合 dio 使用 |
| **web_socket_channel** | WebSocket 客户端 | [web_socket_channel](https://pub.dev/packages/web_socket_channel) | Dart 官方维护，实时消息通信 |
| **connectivity_plus** | 网络状态监听 | [connectivity_plus](https://pub.dev/packages/connectivity_plus) | 监听 WiFi / 移动数据 / 断网状态变化 |

### 4.4 数据持久化

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **drift** | 本地 SQL 数据库 | [drift](https://pub.dev/packages/drift) | 类型安全的 SQLite ORM，支持响应式查询流（Stream），替代 sqflite |
| **shared_preferences** | 键值对存储 | [shared_preferences](https://pub.dev/packages/shared_preferences) | 用户偏好设置、简单配置项 |
| **flutter_secure_storage** | 安全存储 | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | Keychain (iOS) / EncryptedSharedPreferences (Android) 存储敏感凭证 |
| **hive** | 轻量 NoSQL 缓存 | [hive](https://pub.dev/packages/hive) | 高性能键值对存储，适合聊天消息临时缓存 |

### 4.5 UI 组件与动画

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **lottie** | Lottie 动画渲染 | [lottie](https://pub.dev/packages/lottie) | AI 伴侣表情动画、空状态动画、庆祝动画 |
| **cached_network_image** | 图片异步加载与缓存 | [cached_network_image](https://pub.dev/packages/cached_network_image) | 头像、图片消息的加载与内存/磁盘缓存 |
| **shimmer** | 骨架屏加载效果 | [shimmer](https://pub.dev/packages/shimmer) | 列表加载占位、内容加载过渡 |
| **flutter_animate** | 声明式动画库 | [flutter_animate](https://pub.dev/packages/flutter_animate) | 链式动画 API，支持 fade、slide、scale、blur 等组合 |
| **flutter_slidable** | 列表滑动操作 | [flutter_slidable](https://pub.dev/packages/flutter_slidable) | 聊天列表左滑置顶/删除 |
| **photo_view** | 图片查看器 | [photo_view](https://pub.dev/packages/photo_view) | 全屏图片查看，支持双指缩放、拖拽 |
| **image_picker** | 图片/相机选择 | [image_picker](https://pub.dev/packages/image_picker) | 从相册选择或拍照发送图片 |
| **emoji_picker_flutter** | 表情选择器 | [emoji_picker_flutter](https://pub.dev/packages/emoji_picker_flutter) | 聊天输入框的表情键盘 |
| **smooth_page_indicator** | 页面指示器 | [smooth_page_indicator](https://pub.dev/packages/smooth_page_indicator) | 引导页圆点指示器，支持多种动画效果 |
| **flutter_markdown** | Markdown 渲染 | [flutter_markdown](https://pub.dev/packages/flutter_markdown) | AI 回复中的富文本/Markdown 内容渲染 |

### 4.6 音频与语音

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **just_audio** | 音频播放 | [just_audio](https://pub.dev/packages/just_audio) | 语音消息播放、AI 语音朗读，支持流式播放 |
| **record** | 音频录制 | [record](https://pub.dev/packages/record) | 语音消息录制，支持 PCM / AAC 格式 |
| **audio_session** | 音频会话管理 | [audio_session](https://pub.dev/packages/audio_session) | 处理音频焦点、后台播放、与其他 App 音频冲突 |

### 4.7 推送与通知

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **firebase_messaging** | FCM 远程推送 | [firebase_messaging](https://pub.dev/packages/firebase_messaging) | Android 使用 FCM，iOS 通过 FCM 转发至 APNs |
| **flutter_local_notifications** | 本地通知 | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | 定时问候（早安/晚安）、本地提醒 |
| **firebase_core** | Firebase 核心 | [firebase_core](https://pub.dev/packages/firebase_core) | Firebase 服务初始化 |

### 4.8 工具与辅助

| 库名 | 用途 | pub.dev | 说明 |
|------|------|---------|------|
| **freezed** | 不可变数据类代码生成 | [freezed](https://pub.dev/packages/freezed) | 生成 Entity / State 的 copyWith、==、hashCode 等 |
| **json_serializable** | JSON 序列化代码生成 | [json_serializable](https://pub.dev/packages/json_serializable) | 自动fromJson/toJson，配合 freezed 使用 |
| **intl** | 国际化 | [intl](https://pub.dev/packages/intl) | 多语言支持、日期/数字格式化 |
| **url_launcher** | 外部链接跳转 | [url_launcher](https://pub.dev/packages/url_launcher) | 打开浏览器、拨打电话、发邮件 |
| **permission_handler** | 权限管理 | [permission_handler](https://pub.dev/packages/permission_handler) | 统一处理相机、麦克风、存储等权限请求 |
| **very_good_analysis** | Lint 规则集 | [very_good_analysis](https://pub.dev/packages/very_good_analysis) | Very Good Ventures 出品，严格代码规范 |
| **build_runner** | 代码生成运行器 | [build_runner](https://pub.dev/packages/build_runner) | 运行 freezed、json_serializable、riverpod_generator 等 |

---

## 5. 网络层设计

基于 **Dio + Retrofit** 构建类型安全的网络层：

```
├── ApiClient              // Dio 实例配置（baseURL、超时、拦截器）
│   ├── AuthInterceptor    // JWT Token 自动注入 + 过期自动刷新
│   ├── LoggingInterceptor // 请求/响应日志（仅 Debug 模式）
│   └── RetryInterceptor   // 失败自动重试（指数退避）
├── ApiService             // Retrofit 注解式 API 接口定义
│   ├── @POST('/auth/login')
│   ├── @GET('/conversations/{id}/messages')
│   ├── @POST('/messages/send')
│   └── ...
├── WebSocketService       // WebSocket 连接管理
│   ├── connect()          // 建立连接 + 心跳保活
│   ├── sendMessage()      // 发送消息
│   └── messageStream      // Stream<Message> 消息流
└── SSEService             // Server-Sent Events 流式读取
    └── streamChat()       // Stream<String> AI 打字机效果
```

### 5.1 Retrofit API 定义示例

```dart
@RestApi(baseUrl: 'https://api.example.com')
abstract class ApiService {
  factory ApiService(Dio dio) = _ApiService;

  @POST('/auth/login')
  Future<LoginResponse> login(@Body() LoginRequest request);

  @GET('/conversations/{partnerId}/messages')
  Future<List<MessageModel>> getMessages(
    @Path('partnerId') String partnerId,
    @Query('before') String? cursor,
    @Query('limit') int limit = 20,
  );

  @POST('/messages/send')
  Future<MessageModel> sendMessage(@Body() SendMessageRequest request);
}
```

### 5.2 WebSocket 消息流

```dart
class WebSocketService {
  WebSocketChannel? _channel;

  Stream<MessageModel> get messageStream =>
    _channel!.stream
      .map((data) => jsonDecode(data as String))
      .map((json) => MessageModel.fromJson(json));

  void connect(String url, String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('$url?token=$token'),
    );
    _startHeartbeat();
  }
}
```

### 5.3 SSE 流式输出（AI 打字机效果）

```dart
Stream<String> streamChat(String conversationId, String message) async* {
  final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'));
  request.body = jsonEncode({'conversationId': conversationId, 'message': message});
  final response = await http.Client().send(request);

  await for (final chunk in response.stream.transform(utf8.decoder)) {
    for (final line in chunk.split('\n')) {
      if (line.startsWith('data: ')) {
        final token = line.substring(6);
        if (token == '[DONE]') return;
        yield token;
      }
    }
  }
}
```

---

## 6. 本地持久化

| 存储类型 | 技术方案 | 用途 |
|----------|---------|------|
| 结构化数据 | **Drift** (SQLite) | 对话记录、AI 伴侣配置、记忆数据 |
| 响应式查询 | **Drift Stream** | 聊天列表实时更新（数据库变化自动推送到 UI） |
| 键值对存储 | **shared_preferences** | 用户偏好设置、首次启动标记、简单配置 |
| 安全存储 | **flutter_secure_storage** | JWT Token、API Key、敏感凭证 |
| 轻量缓存 | **Hive** | 消息临时缓存、UI 状态快照 |
| 文件缓存 | **cached_network_image** + File | 图片缓存、语音文件、Lottie 动画文件 |

### 6.1 Drift 数据表定义示例

```dart
@DataClassName('PartnerData')
class Partners extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 12)();
  TextColumn get personality => text()();  // JSON 序列化的性格列表
  TextColumn get relationshipType => text()();
  TextColumn get themeColor => text()();
  TextColumn get avatarLottieName => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageData')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get content => text()();
  TextColumn get role => text()();  // 'user' / 'assistant'
  TextColumn get status => text()();  // 'sending' / 'sent' / 'delivered' / 'read'
  DateTimeColumn get timestamp => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 7. 推送与通知

| 通知类型 | 技术方案 | 触发场景 |
|----------|---------|----------|
| 远程推送 | Firebase Messaging (FCM) | AI 伴侣主动关心、系统通知。iOS 通过 FCM 转发至 APNs |
| 本地通知 | flutter_local_notifications | 定时问候（早安/晚安）、日程提醒 |
| 实时消息 | WebSocket 推送 | 在线时的消息实时送达 |
| 前台通知 | flutter_local_notifications | App 在前台时的消息横幅提醒 |

---

## 8. 关键技术决策记录

### 8.1 Riverpod vs Bloc

| 维度 | Riverpod | Bloc |
|------|----------|------|
| 样板代码 | 少（配合 codegen 更少） | 多（Event + State + Bloc 三个文件） |
| 类型安全 | 编译期检查 | 运行时检查 |
| 依赖注入 | 内置 | 需配合 get_it |
| 学习曲线 | 中等 | 较陡 |
| 社区趋势 | 快速增长，Flutter 团队推荐 | 成熟稳定，企业级首选 |

**决策：** 选择 Riverpod。本项目为中等复杂度应用，Riverpod 的低样板代码和内置 DI 能显著提升开发效率。

### 8.2 Drift vs sqflite / Hive

| 维度 | Drift | sqflite | Hive |
|------|-------|---------|------|
| 类型安全 | ✅ 编译期检查 | ❌ 手写 SQL | ❌ 动态类型 |
| 响应式查询 | ✅ Stream 自动推送 | ❌ 需手动轮询 | ✅ Box 监听 |
| 关系查询 | ✅ 支持 JOIN | ✅ 手写 SQL | ❌ 不支持 |
| 复杂查询 | ✅ 强 | ✅ 强 | ❌ 弱 |

**决策：** 结构化数据（对话、伴侣、记忆）使用 Drift，轻量缓存（UI 状态、临时数据）使用 Hive。

### 8.3 go_router vs auto_route

| 维度 | go_router | auto_route |
|------|-----------|------------|
| 维护方 | Flutter 官方团队 | 社区 |
| 声明式 | ✅ | ✅ |
| 深链接 | ✅ 原生支持 | ✅ 支持 |
| ShellRoute | ✅ 内置（底部 Tab） | ✅ 支持 |
| 代码生成 | 可选（go_router_builder） | 必须 |

**决策：** 选择 go_router。Flutter 官方推荐，长期维护有保障，ShellRoute 天然支持底部 Tab 导航。
