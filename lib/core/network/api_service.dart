import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user.dart';
import '../../shared/models/companion.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/message.dart';
import '../../shared/models/memory.dart';
import '../../shared/models/subscription.dart';
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

  /// 获取对话消息
  Future<List<Message>> getMessages(
    int conversationId, {
    int page = 1,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/conversation/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _unwrap(response) as List<dynamic>;
    return data
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 发送消息（非流式）
  Future<Message> sendMessage(SendMessageRequest request) async {
    final response = await _dio.post('/api/chat/send', data: request.toJson());
    return Message.fromJson(_unwrap(response) as Map<String, dynamic>);
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
  Future<CreatePaymentResponse> createPayment(int planId) async {
    final response = await _dio.post(
      '/api/alipay/create',
      data: {'planId': planId},
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

  CreateCompanionRequest({
    required this.name,
    required this.gender,
    required this.relationshipType,
    this.personalityKeys,
    this.speakingStyle,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'relationshipType': relationshipType,
    if (personalityKeys != null) 'personalityKeys': personalityKeys,
    if (speakingStyle != null) 'speakingStyle': speakingStyle,
    if (description != null) 'description': description,
  };
}

/// 发送消息请求
class SendMessageRequest {
  final int conversationId;
  final int companionId;
  final String content;
  final String? contentType;
  final String? sceneMode;

  SendMessageRequest({
    required this.conversationId,
    required this.companionId,
    required this.content,
    this.contentType,
    this.sceneMode,
  });

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'companionId': companionId,
    'content': content,
    if (contentType != null) 'contentType': contentType,
    if (sceneMode != null) 'sceneMode': sceneMode,
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
