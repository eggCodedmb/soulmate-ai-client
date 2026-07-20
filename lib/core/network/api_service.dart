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
import '../../shared/models/memory_stats.dart';
import '../../shared/models/page_result.dart';
import '../../shared/models/subscription.dart';
import '../../shared/models/subscription_status.dart';
import 'api_client.dart';

// Import module mixins
import 'modules/auth_api.dart';
import 'modules/user_api.dart';
import 'modules/companion_api.dart';
import 'modules/chat_api.dart';
import 'modules/memory_api.dart';
import 'modules/subscription_api.dart';
import 'modules/payment_api.dart';
import 'modules/asr_api.dart';
import 'modules/file_api.dart';

// Export module mixins so any file importing api_service.dart also sees the mixins
export 'modules/auth_api.dart';
export 'modules/user_api.dart';
export 'modules/companion_api.dart';
export 'modules/chat_api.dart';
export 'modules/memory_api.dart';
export 'modules/subscription_api.dart';
export 'modules/payment_api.dart';
export 'modules/asr_api.dart';
export 'modules/file_api.dart';

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
class ApiService with
    AuthMixin,
    UserMixin,
    CompanionMixin,
    ChatMixin,
    MemoryMixin,
    SubscriptionMixin,
    PaymentMixin,
    AsrMixin,
    FileMixin {
  final Dio _dio;

  ApiService(this._dio);

  /// 暴露 dio 给 Mixins 使用
  Dio get dio => _dio;

  /// 暴露 unwrap 给 Mixins 使用
  dynamic unwrap(Response<dynamic> response) => _unwrap(response);
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
  final DateTime? birthday;
  final TtsConfig? ttsConfig;

  CreateCompanionRequest({
    required this.name,
    required this.gender,
    required this.relationshipType,
    this.personalityKeys,
    this.speakingStyle,
    this.description,
    this.birthday,
    this.ttsConfig,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'relationshipType': relationshipType,
    if (personalityKeys != null) 'personalityKeys': personalityKeys,
    if (speakingStyle != null) 'speakingStyle': speakingStyle,
    if (description != null) 'description': description,
    'birthday': birthday?.toIso8601String(),
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
