import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/page_result.dart';
import '../api_service.dart';

/// 对话与聊天模块 API
mixin ChatMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 创建或获取对话
  Future<Conversation> createConversation(int companionId) async {
    final response = await dio.post<dynamic>(
      '/api/conversation',
      queryParameters: {'companionId': companionId},
    );
    return Conversation.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 获取对话列表
  Future<List<Conversation>> getConversationList() async {
    final response = await dio.get<dynamic>('/api/conversation/list');
    final data = unwrap(response) as List<dynamic>;
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
    final response = await dio.get<dynamic>(
      '/api/conversation/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final data = unwrap(response) as Map<String, dynamic>;
    return PageResult.fromJson(data, Message.fromJson);
  }

  /// 发送消息（非流式）
  Future<Message> sendMessage(SendMessageRequest request) async {
    final response = await dio.post<dynamic>('/api/chat/send', data: request.toJson());
    return Message.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 发送消息（SSE流式）
  ///
  /// 返回 `Stream<ChatResponse>`，逐 chunk 推送 AI 回复。
  /// 当 ChatResponse.done == true 时流结束。
  Stream<ChatResponse> streamChat(
    SendMessageRequest request, {
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<ChatResponse>();

    () async {
      try {
        final response = await dio.post<ResponseBody>(
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

        var chunkCount = 0;
        final rawBuffer = StringBuffer();

        await for (final line in lineStream) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          // 支持标准 SSE 格式 (data: {...}) 和纯 JSON 格式 ({...})
          String? jsonStr;
          if (trimmedLine.startsWith('data:')) {
            jsonStr = trimmedLine.substring(5).trim();
          } else if (trimmedLine.startsWith('{') && trimmedLine.endsWith('}')) {
            // 兼容纯 JSON 行（非标准 SSE 格式）
            jsonStr = trimmedLine;
          }

          if (jsonStr == null || jsonStr.isEmpty) continue;
          if (jsonStr == '[DONE]') break;

          try {
            final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
            final chatResponse = ChatResponse.fromJson(jsonMap);
            chunkCount++;
            if (chatResponse.content != null) {
              rawBuffer.write(chatResponse.content);
            }
            debugPrint('SSE chunk #$chunkCount: content="${chatResponse.content}", done=${chatResponse.done}, totalLen=${rawBuffer.length}');
            controller.add(chatResponse);

            if (chatResponse.done) {
              debugPrint('SSE流完成: 共收到 $chunkCount 个chunk, 总长度 ${rawBuffer.length}');
              if (!controller.isClosed) await controller.close();
              return;
            }
          } on FormatException catch (e) {
            debugPrint('SSE JSON解析失败: $jsonStr, error: $e');
          }
        }

        debugPrint('SSE流结束(无done标记): 共收到 $chunkCount 个chunk, 总长度 ${rawBuffer.length}');
        // 流正常结束 but 没收到 done=true
        if (!controller.isClosed) {
          await controller.close();
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          debugPrint('SSE流被取消');
        } else {
          debugPrint('SSE流异常: ${e.type} ${e.message}');
          controller.add(const ChatResponse(
            error: '网络异常，请稍后重试',
            done: true,
          ));
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      } on Object catch (e) {
        debugPrint('SSE流未知异常: $e');
        controller.add(const ChatResponse(
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
}
