import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/tts_config.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/message.dart';
import '../../shared/models/memory.dart';
import '../../shared/models/page_result.dart';
import '../../shared/models/subscription.dart';
import '../../shared/models/reminder.dart';
import 'api_client.dart';

/// API 异常
class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => 'ApiException($code): $message';
}

/// 解包 R 响应体，校验 code 并返回 data
dynamic _unwrap(Response<dynamic> response) {
  final body = response.data as Map<String, dynamic>;
  final code = body['code'] as int? ?? -1;
  if (code != 0) {
    throw ApiException(code, body['message'] as String? ?? '请求失败');
  }
  return body['data'];
}

/// SoulMate AI API服务
class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  // ==================== 认证模块 ====================

  /// 发送验证码
  Future<void> sendVerifyCode(Map<String, String> body) async {
    final response = await _dio.post('/api/auth/send-code', data: body);
    _unwrap(response); // 校验 code
  }

  /// 邮箱验证码登录
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post('/api/auth/login', data: request.toJson());
    return LoginResponse.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 游客登录
  Future<LoginResponse> guestLogin() async {
    final response = await _dio.post('/api/auth/guest');
    return LoginResponse.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  // ==================== 用户模块 ====================

  /// 获取用户信息
  Future<User> getUserInfo() async {
    final response = await _dio.get('/api/user/info');
    return User.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户信息
  Future<void> updateUserInfo(User user) async {
    final response = await _dio.put('/api/user/info', data: user.toJson());
    _unwrap(response);
  }

  /// 更新用户头像
  Future<void> updateAvatar(String? avatarUrl) async {
    final response = await _dio.put(
      '/api/user/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    _unwrap(response);
  }

  /// 获取用户资料
  Future<UserProfile> getUserProfile() async {
    final response = await _dio.get('/api/user/profile');
    return UserProfile.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户资料
  Future<void> updateUserProfile(UserProfile profile) async {
    final response = await _dio.put('/api/user/profile', data: profile.toJson());
    _unwrap(response);
  }

  /// 获取用户设置
  Future<UserSettings> getUserSettings() async {
    final response = await _dio.get('/api/user/settings');
    return UserSettings.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 更新用户设置
  Future<void> updateUserSettings(UserSettings settings) async {
    final response = await _dio.put('/api/user/settings', data: settings.toJson());
    _unwrap(response);
  }

  // ==================== AI伴侣模块 ====================

  /// 创建伴侣
  Future<Companion> createCompanion(CreateCompanionRequest request) async {
    final response = await _dio.post('/api/companion', data: request.toJson());
    return Companion.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 获取伴侣列表
  Future<List<Companion>> getCompanionList() async {
    final response = await _dio.get('/api/companion/list');
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => Companion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取伴侣详情
  Future<Companion> getCompanion(int id) async {
    final response = await _dio.get('/api/companion/$id');
    return Companion.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 更新伴侣
  Future<void> updateCompanion(int id, Companion companion) async {
    final response = await _dio.put('/api/companion/$id', data: companion.toJson());
    _unwrap(response);
  }

  /// 更新伴侣头像
  Future<void> updateCompanionAvatar(int id, String? avatarUrl) async {
    final response = await _dio.put(
      '/api/companion/$id/avatar',
      data: {'avatarUrl': avatarUrl},
    );
    _unwrap(response);
  }

  /// 删除伴侣
  Future<void> deleteCompanion(int id) async {
    final response = await _dio.delete('/api/companion/$id');
    _unwrap(response);
  }

  // ==================== 对话与聊天模块 ====================

  /// 创建或获取对话
  Future<Conversation> createConversation(int companionId) async {
    final response = await _dio.post(
      '/api/conversation',
      queryParameters: {'companionId': companionId},
    );
    return Conversation.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 获取对话列表
  Future<List<Conversation>> getConversationList() async {
    final response = await _dio.get('/api/conversation/list');
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取对话消息（分页）
  Future<PageResult<Message>> getMessages(
    int conversationId, {
    int page = 1,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/conversation/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _unwrap(response) as Map<String, dynamic>;
    return PageResult.fromJson(data, Message.fromJson);
  }

  /// 发送消息（非流式）
  Future<Message> sendMessage(SendMessageRequest request) async {
    final response = await _dio.post('/api/chat/send', data: request.toJson());
    return Message.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 发送消息（SSE流式）
  ///
  /// 返回 Stream<ChatResponse>，逐 chunk 推送 AI 回复。
  /// 当 ChatResponse.done == true 时流结束。
  Stream<ChatResponse> streamChat(
    SendMessageRequest request, {
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<ChatResponse>();

    () async {
      try {
        final response = await _dio.post<ResponseBody>(
          '/api/chat/stream',
          data: request.toJson(),
          options: Options(
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(seconds: 120),
            headers: {'Accept': 'text/event-stream'},
          ),
          cancelToken: cancelToken,
        );

        final stream = response.data!.stream;

        // 使用 Utf8Decoder 和 LineSplitter 自动处理字节合并与按行切分
        // 这样可以解决中文乱码问题，并且让流处理更及时
        final lineStream = stream
            .cast<List<int>>() // 显式转换类型以匹配 Utf8Decoder
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lineStream) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          if (trimmedLine.startsWith('data:')) {
            final jsonStr = trimmedLine.substring(5).trim();
            if (jsonStr.isEmpty) continue;
            if (jsonStr == '[DONE]') break;

            try {
              final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
              final chatResponse = ChatResponse.fromJson(jsonMap);
              controller.add(chatResponse);

              if (chatResponse.done) {
                if (!controller.isClosed) await controller.close();
                return;
              }
            } catch (e) {
              debugPrint('SSE JSON解析失败: $jsonStr, error: $e');
            }
          }
        }

        // 流正常结束但没收到 done=true
        if (!controller.isClosed) {
          await controller.close();
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          debugPrint('SSE流被取消');
        } else {
          debugPrint('SSE流异常: ${e.type} ${e.message}');
          controller.add(ChatResponse(
            error: '网络异常，请稍后重试',
            done: true,
          ));
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e) {
        debugPrint('SSE流未知异常: $e');
        controller.add(ChatResponse(
          error: 'AI服务暂时不可用',
          done: true,
        ));
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  // ==================== 记忆模块 ====================

  /// 获取记忆列表
  Future<List<Memory>> getMemoryList({
    int? companionId,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{};
    if (companionId != null) queryParams['companionId'] = companionId;
    if (category != null) queryParams['category'] = category;

    final response = await _dio.get(
      '/api/memory/list',
      queryParameters: queryParams,
    );
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 更新记忆
  Future<void> updateMemory(int id, Memory memory) async {
    final response = await _dio.put('/api/memory/$id', data: memory.toJson());
    _unwrap(response);
  }

  /// 删除记忆
  Future<void> deleteMemory(int id) async {
    final response = await _dio.delete('/api/memory/$id');
    _unwrap(response);
  }

  // ==================== 订阅模块 ====================

  /// 获取套餐列表
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final response = await _dio.get('/api/subscription/plans');
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取当前订阅
  Future<UserSubscription> getCurrentSubscription() async {
    final response = await _dio.get('/api/subscription/current');
    return UserSubscription.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  // ==================== 支付模块 ====================

  /// 创建支付订单
  ///
  /// [paymentChannel] 支付渠道: 'alipay'(支付宝) / 'wechat'(微信) / 'unionpay'(云闪付)
  Future<CreatePaymentResponse> createPayment(
    int planId, {
    String paymentChannel = 'alipay',
  }) async {
    final response = await _dio.post(
      '/api/alipay/create',
      data: {'planId': planId, 'paymentChannel': paymentChannel},
    );
    return CreatePaymentResponse.fromJson(
      _unwrap(response) as Map<String, dynamic>,
    );
  }

  /// 查询支付订单状态
  Future<PaymentOrder> getPaymentStatus(String orderNo) async {
    final response = await _dio.get(
      '/api/alipay/status',
      queryParameters: {'orderNo': orderNo},
    );
    return PaymentOrder.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  // ==================== ASR 语音识别模块 ====================

  /// 语音转文字
  ///
  /// 上传音频文件到 ASR 服务，返回识别出的文字。
  /// 支持格式：WAV, MP3, M4A, WEBM, OGG, FLAC（最大 25MB）
  Future<String> transcribeAudio(String audioFilePath) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioFilePath),
    });
    final response = await _dio.post('/api/asr/transcribe', data: formData);
    final data = _unwrap(response);
    return data as String? ?? '';
  }

  // ==================== 文件上传模块 ====================

  /// 单文件上传
  Future<UploadResult> uploadFile(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/api/file/upload', data: formData);
    return UploadResult.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 删除文件
  Future<void> deleteFile(String filePath) async {
    final response = await _dio.delete(
      '/api/file/delete',
      queryParameters: {'filePath': filePath},
    );
    _unwrap(response);
  }

  /// 获取定时提醒列表
  Future<List<Reminder>> getReminderList() async {
    final response = await _dio.get('/api/reminders/list');
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取定时提醒详情
  Future<Reminder> getReminderDetail(int id) async {
    final response = await _dio.get('/api/reminders/$id');
    return Reminder.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 创建定时提醒
  Future<Reminder> createReminder({
    required int companionId,
    required String reminderTime,
    required String textTemplate,
    required String type,
    String repeatDays = '',
    int enabled = 1,
  }) async {
    final response = await _dio.post(
      '/api/reminders',
      data: {
        'companionId': companionId,
        'reminderTime': reminderTime,
        'textTemplate': textTemplate,
        'type': type,
        'repeatDays': repeatDays,
        'enabled': enabled,
      },
    );
    return Reminder.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  /// 更新定时提醒
  Future<void> updateReminder(int id, {
    int? companionId,
    String? reminderTime,
    String? textTemplate,
    String? type,
    String? repeatDays,
    int? enabled,
  }) async {
    final response = await _dio.put(
      '/api/reminders/$id',
      data: {
        if (companionId != null) 'companionId': companionId,
        if (reminderTime != null) 'reminderTime': reminderTime,
        if (textTemplate != null) 'textTemplate': textTemplate,
        if (type != null) 'type': type,
        if (repeatDays != null) 'repeatDays': repeatDays,
        if (enabled != null) 'enabled': enabled,
      },
    );
    _unwrap(response);
  }

  /// 删除定时提醒
  Future<void> deleteReminder(int id) async {
    final response = await _dio.delete('/api/reminders/$id');
    _unwrap(response);
  }
}

/// API服务Provider（使用Riverpod）
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});

// ==================== 请求/响应 DTO ====================

/// 登录请求
class LoginRequest {
  final String email;
  final String verifyCode;

  LoginRequest({required this.email, required this.verifyCode});

  Map<String, dynamic> toJson() => {
    'email': email,
    'verifyCode': verifyCode,
  };
}

/// 登录响应
class LoginResponse {
  final String token;
  final int userId;
  final String? nickname;
  final String? avatarUrl;
  final bool isNewUser;

  LoginResponse({
    required this.token,
    required this.userId,
    this.nickname,
    this.avatarUrl,
    this.isNewUser = false,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String? ?? '',
      userId: (json['userId'] as num).toInt(),
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}

/// 创建伴侣请求
class CreateCompanionRequest {
  final String name;
  final int gender;
  final String relationshipType;
  final List<String>? personalityKeys;
  final String? speakingStyle;
  final String? description;
  final TtsConfig? ttsConfig;

  CreateCompanionRequest({
    required this.name,
    required this.gender,
    required this.relationshipType,
    this.personalityKeys,
    this.speakingStyle,
    this.description,
    this.ttsConfig,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'relationshipType': relationshipType,
    if (personalityKeys != null) 'personalityKeys': personalityKeys,
    if (speakingStyle != null) 'speakingStyle': speakingStyle,
    if (description != null) 'description': description,
    if (ttsConfig != null) 'ttsConfig': ttsConfig!.toJson(),
  };
}

/// 发送消息请求
class SendMessageRequest {
  final int conversationId;
  final int companionId;
  final String content;
  final String? contentType;
  final String? sceneMode;

  /// LLM 模型配置（可选，不传则使用后端默认模型）
  final String? llmProviderType;
  final String? llmBaseUrl;
  final String? llmApiKey;
  final String? llmModel;

  SendMessageRequest({
    required this.conversationId,
    required this.companionId,
    required this.content,
    this.contentType,
    this.sceneMode,
    this.llmProviderType,
    this.llmBaseUrl,
    this.llmApiKey,
    this.llmModel,
  });

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'companionId': companionId,
    'content': content,
    if (contentType != null) 'contentType': contentType,
    if (sceneMode != null) 'sceneMode': sceneMode,
    if (llmProviderType != null) 'llmProviderType': llmProviderType,
    if (llmBaseUrl != null) 'llmBaseUrl': llmBaseUrl,
    if (llmApiKey != null) 'llmApiKey': llmApiKey,
    if (llmModel != null) 'llmModel': llmModel,
  };
}

/// 文件上传结果
class UploadResult {
  final String fileName;
  final String savedName;
  final String filePath;
  final String url;
  final int fileSize;
  final String fileType;

  UploadResult({
    required this.fileName,
    required this.savedName,
    required this.filePath,
    required this.url,
    required this.fileSize,
    required this.fileType,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      fileName: json['fileName'] as String? ?? '',
      savedName: json['savedName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      url: json['url'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      fileType: json['fileType'] as String? ?? '',
    );
  }
}
