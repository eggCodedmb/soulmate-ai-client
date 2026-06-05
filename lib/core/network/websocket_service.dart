import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/secure_storage.dart';

/// WebSocket服务 - 实时消息通信
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _heartbeatTimer;
  bool _isConnected = false;

  /// 消息流
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 连接WebSocket
  Future<void> connect(String url) async {
    if (_isConnected) return;

    try {
      final token = await SecureStorage.getToken();
      _channel = WebSocketChannel.connect(
        Uri.parse('$url?token=$token'),
      );

      // 监听消息
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(json);
          } catch (e) {
            print('WebSocket消息解析错误: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          _stopHeartbeat();
          // TODO: 实现断线重连逻辑
        },
        onError: (error) {
          _isConnected = false;
          _stopHeartbeat();
          print('WebSocket错误: $error');
        },
      );

      _isConnected = true;
      _startHeartbeat();
    } catch (e) {
      _isConnected = false;
      print('WebSocket连接失败: $e');
    }
  }

  /// 发送消息
  void sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// 断开连接
  void disconnect() {
    _stopHeartbeat();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// 开始心跳
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        sendMessage({'type': 'ping'});
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
