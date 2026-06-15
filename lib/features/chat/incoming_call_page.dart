import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:vad/vad.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/network/asr_api_client.dart';
import '../../core/utils/audio_utils.dart';
import '../../core/services/vad_service.dart';
import '../../shared/models/reminder.dart';
import '../../shared/models/companion.dart';
import '../../shared/widgets/soul_toast.dart';
import 'tts_audio_service.dart';

enum CallSessionState {
  connecting,
  speaking,
  listening,
  thinking,
}

class IncomingCallPage extends ConsumerStatefulWidget {
  final int reminderId;
  final Reminder? reminder;
  final bool isOutgoing;
  final int? conversationId;

  const IncomingCallPage({
    super.key,
    required this.reminderId,
    this.reminder,
    this.isOutgoing = false,
    this.conversationId,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with TickerProviderStateMixin {
  
  Reminder? _reminder;
  Companion? _companion;
  bool _isLoading = false;
  bool _isConnected = false;
  
  CallSessionState _callState = CallSessionState.connecting;
  WebSocketChannel? _channel;
  late final TtsAudioService _ttsAudioService;
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isContinuousMode = true; // 顺承对话模式（自动触发麦克风）
  
  String _sentenceBuffer = '';
  int _messageIndex = 0;
  Future<void>? _ttsTaskChain;
  bool _isStreamDone = true;
  int _pendingTtsCount = 0;
  
  bool _isBackgroundGreetingSent = false;
  final List<String> _pendingAudioPaths = [];
  
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  
  // 振铃动效 Controller
  late AnimationController _rippleController;
  // 声波跳动 Controller
  late AnimationController _waveController;
  final List<double> _waveHeights = List.filled(7, 10.0);
  final math.Random _random = math.Random();

  // 通话时长
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
    
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (_isConnected) {
          if (_callState == CallSessionState.speaking) {
            // AI 说话时：基于 TTS 播放器的真实播放音量驱动波形
            final isPlaying = _ttsAudioService.isPlaying;
            setState(() {
              for (int i = 0; i < _waveHeights.length; i++) {
                if (isPlaying) {
                  final base = 15.0 + _random.nextDouble() * 35.0;
                  final distFromCenter = (i - _waveHeights.length / 2).abs() / (_waveHeights.length / 2);
                  _waveHeights[i] = base * (1.0 - distFromCenter * 0.4);
                } else {
                  _waveHeights[i] = 10.0;
                }
              }
            });
          } else if (_callState != CallSessionState.listening) {
            // 非倾听、非播放状态（connecting/thinking）：静止
            setState(() {
              for (int i = 0; i < _waveHeights.length; i++) {
                _waveHeights[i] = 10.0;
              }
            });
          }
          // listening 状态的波形由 build 方法中的 Provider watch 控制
        }
      });

    // 初始化 TTS 音频服务
    _ttsAudioService = setOnStateChangedCallback();

    _initRingtoneAndLoad();
  }

  /// 提取 TTS 状态回调逻辑以便复用
  TtsAudioService setOnStateChangedCallback() {
    final service = TtsAudioService(ref.read(ttsApiProvider));
    service.setOnStateChanged(() {
      if (!mounted) return;
      
      final isPlaying = service.isPlaying;
      debugPrint('[IncomingCall] onStateChanged: isPlaying=$isPlaying, callState=$_callState, isStreamDone=$_isStreamDone, pendingTtsCount=$_pendingTtsCount');
      
      if (isPlaying) {
        if (_callState != CallSessionState.speaking) {
          setState(() {
            _callState = CallSessionState.speaking;
          });
          // AI 说话时，停止用户麦克风录音，防止自言自语/串音
          _stopUserRecording(send: false);
        }
      } else if (!isPlaying && (_callState == CallSessionState.speaking || _callState == CallSessionState.thinking)) {
        // AI 播放完成或停止（涵盖 Completed/Idle/Error 等所有非播放状态），必须流已结束且无 pending 的 TTS 生成任务，才切换到倾听状态
        if (_isStreamDone && _pendingTtsCount == 0) {
          setState(() {
            _callState = CallSessionState.listening;
          });
          // 仅在开启了顺承模式时才自动触发录音
          if (_isContinuousMode) {
            _startUserRecording();
          }
        } else {
          debugPrint('[IncomingCall] AI播放列表暂时空闲，等待后续音频生成... streamDone: $_isStreamDone, pendingTtsCount: $_pendingTtsCount');
        }
      }
    });
    return service;
  }

  Future<void> _initRingtoneAndLoad() async {
    // 1. 如果尚未加载，先加载数据
    if (_reminder == null) {
      setState(() => _isLoading = true);
      try {
        final apiService = ref.read(apiServiceProvider);
        final detail = await apiService.getReminderDetail(widget.reminderId);
        setState(() {
          _reminder = detail;
        });
      } catch (e) {
        debugPrint('获取闹钟详情失败: $e');
        _hangup();
        return;
      } finally {
        setState(() => _isLoading = false);
      }
    }

    if (_reminder != null && _companion == null) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final comp = await apiService.getCompanion(_reminder!.companionId);
        setState(() {
          _companion = comp;
        });
      } catch (e) {
        debugPrint('获取伴侣信息失败: $e');
      }
    }

    // 2. 预接通 WebSocket，提高接通瞬间响应速度
    await _connectWebSocket();

    // 3. 处理呼入/呼出逻辑
    if (!widget.isOutgoing) {
      // 播放振铃（循环播放本地电话铃声）
      try {
        await _ringtonePlayer.setAsset('assets/audio/phone_ringtone.wav');
        await _ringtonePlayer.setLoopMode(LoopMode.one);
        _ringtonePlayer.play();
      } catch (e) {
        debugPrint('播放铃声失败: $e');
      }
    } else {
      // 从聊天页主动发起的 AI 通话：播放呼叫铃声
      try {
        await _ringtonePlayer.setAsset('assets/audio/phone_ringtone.wav');
        await _ringtonePlayer.setLoopMode(LoopMode.one);
        _ringtonePlayer.play();
      } catch (e) {
        debugPrint('播放铃声失败: $e');
      }

      // 铃声播放同时，后台立刻发送指令让 AI 开始思考
      _isBackgroundGreetingSent = true;
      _playInitialGreeting();

      // 延长几秒（4.5秒）后自动接通，这个时间刚好给 AI 用来思考和生成语音
      Future.delayed(const Duration(milliseconds: 4500), () {
        if (mounted && !_isConnected) {
          _answer();
        }
      });
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _rippleController.dispose();
    _waveController.dispose();
    _ringtonePlayer.dispose();
    _ttsAudioService.dispose();
    _recorder.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // 挂断
  Future<void> _hangup() async {
    HapticFeedback.mediumImpact();
    _ringtonePlayer.stop();
    _ttsAudioService.stop();
    
    await ref.read(vadNotifierProvider.notifier).stopListening();
    
    _callTimer?.cancel();
    _channel?.sink.close();
    if (mounted) {
      context.pop();
    }
  }

  // 接听
  Future<void> _answer() async {
    HapticFeedback.heavyImpact();
    _ringtonePlayer.stop();
    _rippleController.stop();

    setState(() {
      _isConnected = true;
      _callState = CallSessionState.connecting;
    });

    _waveController.repeat(reverse: true);
    
    // 启动时长计时器
    _startCallTimer();

    // 建立 WebSocket 连接（避免重复）
    await _connectWebSocket();

    if (!_isBackgroundGreetingSent) {
      // 如果没有后台发送过，现在播放伴侣初始问候语/叫醒词
      await _playInitialGreeting();
    } else {
      // 把呼叫期间积攒的音频播放出来
      if (_pendingAudioPaths.isNotEmpty) {
        setState(() {
          _callState = CallSessionState.speaking;
        });
        for (int i = 0; i < _pendingAudioPaths.length; i++) {
          await _ttsAudioService.enqueue(_pendingAudioPaths[i], 'call_msg_bg_$i');
        }
        _pendingAudioPaths.clear();
      } else {
        // 如果 4.5 秒 AI 还没返回，或者仍在接收流，显示思考中
        setState(() {
          _callState = CallSessionState.thinking;
        });
      }
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getWsUrl() {
    final apiClient = ref.read(apiClientProvider);
    final baseUrl = apiClient.currentBaseUrl;
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}/ws/call';
  }

  Future<void> _connectWebSocket() async {
    if (_channel != null) return; // 避免重复连接
    final wsUrl = _getWsUrl();
    final token = await SecureStorage.getToken();
    debugPrint('[IncomingCall] 连接 WebSocket: $wsUrl');
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );
      
      _channel!.stream.listen(
        _onWebSocketMessage,
        onDone: _onWebSocketDone,
        onError: _onWebSocketError,
      );
      debugPrint('[IncomingCall] WebSocket 连接成功建立');
    } catch (e) {
      debugPrint('[IncomingCall] WebSocket 连接失败: $e');
      _hangup();
    }
  }

  void _onWebSocketMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final action = json['action'];
      if (action == 'speak') {
        final content = json['content'] as String?;
        final done = json['done'] as bool? ?? false;
        final error = json['error'] as String?;
        
        if (error != null) {
          debugPrint('[IncomingCall] 服务端返回错误: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
          _isStreamDone = true;
          return;
        }
        
        if (done) {
          _isStreamDone = true;
        }
        
        if (content != null && content.isNotEmpty) {
          _sentenceBuffer += content;
          _checkAndPlaySentence(done: done);
        } else if (done) {
          _checkAndPlaySentence(done: true);
        }
      } else if (action == 'interrupt-ack') {
        debugPrint('[IncomingCall] 收到打断 ACK 确认');
      }
    } catch (e) {
      debugPrint('[IncomingCall] 解析 WebSocket 消息异常: $e');
    }
  }

  void _onWebSocketDone() {
    debugPrint('[IncomingCall] WebSocket 连接关闭');
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('[IncomingCall] WebSocket 错误: $error');
  }

  String _cleanTextForVoice(String text) {
    // 移除星号及其包裹的非言语内容
    text = text.replaceAll(RegExp(r'\*.*?\*'), '');
    // 移除各种括号及其包裹的内容（包含中英文括号、方括号）
    text = text.replaceAll(RegExp(r'\(.*?\)|（.*?）'), '');
    text = text.replaceAll(RegExp(r'\[.*?\]|【.*?】'), '');
    return text.trim();
  }

  Future<void> _checkAndPlaySentence({bool done = false}) async {
    final companion = _companion;
    final config = getEffectiveTtsConfig(companion?.ttsConfig);
    if (config == null) {
      debugPrint('[IncomingCall] 无法获取有效的 TTS 配置');
      return;
    }
    
    // 只在整句结束符（句号、问号、感叹号、分号、换行符）处进行断句，避免在逗号处断句导致语音读起来断断续续
    final RegExp punctuation = RegExp(r'[。！？\.\?!;\n]');
    
    if (done) {
      final text = _sentenceBuffer.trim();
      if (text.isNotEmpty) {
        _sentenceBuffer = '';
        final cleanedText = _cleanTextForVoice(text);
        if (cleanedText.isNotEmpty) {
          final index = _messageIndex;
          debugPrint('[IncomingCall] 播放最后一段 AI 语音: "$cleanedText" (原始文本: "$text")');
          
          _pendingTtsCount++;
          _ttsTaskChain = (_ttsTaskChain ?? Future.value()).then((_) async {
            try {
              if (!mounted) return;
              final path = await _ttsAudioService.generateAndCache(cleanedText, config);
              if (path != null && mounted) {
                if (_isConnected) {
                  await _ttsAudioService.enqueue(path, 'call_msg_$index');
                } else {
                  _pendingAudioPaths.add(path);
                }
              }
            } finally {
              debugPrint('[IncomingCall] finally block(done): pendingTtsCount before decrement: $_pendingTtsCount');
              _pendingTtsCount--;
              _checkIfAllDone();
            }
          }).catchError((e) {
            debugPrint('[IncomingCall] TTS播放链错误(done): $e');
          });
        } else {
          _checkIfAllDone();
        }
      } else {
        _checkIfAllDone();
      }
      return;
    }
    
    int lastPuncIndex = -1;
    for (int i = _sentenceBuffer.length - 1; i >= 0; i--) {
      if (punctuation.hasMatch(_sentenceBuffer[i])) {
        lastPuncIndex = i;
        break;
      }
    }
    
    if (lastPuncIndex != -1) {
      final text = _sentenceBuffer.substring(0, lastPuncIndex + 1).trim();
      _sentenceBuffer = _sentenceBuffer.substring(lastPuncIndex + 1);
      
      if (text.isNotEmpty) {
        final cleanedText = _cleanTextForVoice(text);
        if (cleanedText.isNotEmpty) {
          final index = _messageIndex;
          debugPrint('[IncomingCall] 播放分段 AI 语音: "$cleanedText" (原始文本: "$text")');
          
          _pendingTtsCount++;
          _ttsTaskChain = (_ttsTaskChain ?? Future.value()).then((_) async {
            try {
              if (!mounted) return;
              final path = await _ttsAudioService.generateAndCache(cleanedText, config);
              if (path != null && mounted) {
                if (_isConnected) {
                  await _ttsAudioService.enqueue(path, 'call_msg_$index');
                } else {
                  _pendingAudioPaths.add(path);
                }
              }
            } finally {
              debugPrint('[IncomingCall] finally block(punc): pendingTtsCount before decrement: $_pendingTtsCount');
              _pendingTtsCount--;
              _checkIfAllDone();
            }
          }).catchError((e) {
            debugPrint('[IncomingCall] TTS播放链错误(punc): $e');
          });
        }
      }
    }
  }

  void _checkIfAllDone() {
    if (!mounted) return;
    final isPlaying = _ttsAudioService.isPlaying;
    debugPrint('[IncomingCall] _checkIfAllDone: isStreamDone=$_isStreamDone, pendingTtsCount=$_pendingTtsCount, isPlaying=$isPlaying, callState=$_callState');
    if (_isStreamDone && _pendingTtsCount == 0 && 
        !isPlaying && 
        (_callState == CallSessionState.speaking || _callState == CallSessionState.thinking)) {
      debugPrint('[IncomingCall] 所有 TTS 任务及播放均已完成，自动切换回听状态');
      setState(() {
        _callState = CallSessionState.listening;
      });
      // 仅在开启了顺承模式时才自动触发录音
      if (_isContinuousMode) {
        _startUserRecording();
      }
    }
  }

  Future<void> _playInitialGreeting() async {
    // 防御性等待：如果 _reminder 仍在加载，等待其加载完毕
    while (_isLoading && _reminder == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    final reminder = _reminder;
    if (reminder == null) {
      debugPrint('[IncomingCall] _reminder 未加载成功，将直接切换到倾听状态');
      setState(() {
        _callState = CallSessionState.listening;
      });
      _startUserRecording();
      return;
    }
    
    if (_companion == null) {
      try {
        final apiService = ref.read(apiServiceProvider);
        _companion = await apiService.getCompanion(reminder.companionId);
      } catch (e) {
        debugPrint('获取伴侣信息失败: $e');
      }
    }
    
    // 我们仍需要获取 _companion 以提取昵称、头像和伴侣专属的 TTS 音色配置
    // 但不再直接播放本地固定的静态模版，而是通过 WebSocket 发送指令，向大模型请求生成动态的开场白
    debugPrint('[IncomingCall] 向 AI 发送 [GREETING] 指令以动态生成开场白...');
    
    setState(() {
      _callState = CallSessionState.thinking; // 在大模型吐出文本前，界面处于“思考中...”
    });
    
    if (_channel != null) {
      final payload = {
        'action': 'speak',
        'companionId': reminder.companionId,
        'conversationId': widget.conversationId ?? 0,
        'content': '[GREETING]',
      };
      _isStreamDone = false; // 表示开始等待 AI 的流式响应
      _channel!.sink.add(jsonEncode(payload));
    } else {
      // 降级兜底：若通道未连接，则直接切换到倾听状态，由用户开启发言
      setState(() {
        _callState = CallSessionState.listening;
      });
      _startUserRecording();
    }
  }

  Future<void> _startUserRecording() async {
    if (_callState != CallSessionState.listening) return;
    final vadState = ref.read(vadNotifierProvider);
    if (vadState.isRecording) return;
    
    try {
      if (!await _recorder.hasPermission()) {
        debugPrint('[IncomingCall] 录音权限未授予');
        return;
      }

      await ref.read(vadNotifierProvider.notifier).startListening();
    } catch (e) {
      debugPrint('[IncomingCall] VAD 开始录音失败: $e');
    }
  }

  Future<void> _stopUserRecording({required bool send}) async {
    await ref.read(vadNotifierProvider.notifier).stopListening();
    
    // VAD 模式下，自动断句通过 onSpeechEnd 触发。
    // 如果是手动停止（如被打断），通常不需要额外处理，除非 send 为 true。
    // 但通话场景下 send 通常由 onSpeechEnd 自动触发。
  }

  void _doneSpeakingWithFile(String path) {
    _stopUserRecording(send: false); // 先停止 VAD 监听
    _processAndSendUserVoice(path);
  }

  Future<void> _processAndSendUserVoice(String path) async {
    if (!mounted) return;
    setState(() {
      _callState = CallSessionState.thinking;
    });
    
    try {
      String transcribedText = '';
      if (LocalStorage.asrProviderType == 'custom') {
        final asrClient = AsrApiClient();
        transcribedText = await asrClient.transcribe(path);
      } else {
        final apiService = ref.read(apiServiceProvider);
        transcribedText = await apiService.transcribeAudio(path);
      }
      
      // 删除临时文件
      try {
        await File(path).delete();
      } catch (_) {}
      
      if (!mounted) return;
      
      if (transcribedText.trim().isEmpty) {
        debugPrint('[IncomingCall] ASR 未识别到任何文字');
        setState(() {
          _callState = CallSessionState.listening;
        });
        _startUserRecording();
        return;
      }
      
      debugPrint('[IncomingCall] ASR 识别成功: "$transcribedText"');
      _messageIndex++;
      if (_channel != null) {
        final payload = {
          'action': 'speak',
          'companionId': _reminder?.companionId,
          'conversationId': widget.conversationId ?? 0,
          'content': transcribedText,
        };
        _isStreamDone = false; // 重置流结束标志，表示开始等待新的AI回复流
        _channel!.sink.add(jsonEncode(payload));
      } else {
        debugPrint('[IncomingCall] WebSocket 未连接，无法发送消息');
        setState(() {
          _callState = CallSessionState.listening;
        });
        _startUserRecording();
      }
    } catch (e) {
      debugPrint('[IncomingCall] 语音处理/发送异常: $e');
      if (mounted) {
        setState(() {
          _callState = CallSessionState.listening;
        });
        _startUserRecording();
      }
    }
  }

  Future<void> _interrupt() async {
    if (_channel != null) {
      final payload = {
        'action': 'interrupt',
        'conversationId': widget.conversationId ?? 0,
      };
      _channel!.sink.add(jsonEncode(payload));
    }
    
    // 立即停止本地 TTS 播放并清理句子缓存
    await _ttsAudioService.stop();
    _sentenceBuffer = '';
    _ttsTaskChain = null;
    _isStreamDone = true; // 强制打断设置为true
    _pendingTtsCount = 0; // 重置计数器
    
    setState(() {
      _callState = CallSessionState.listening;
    });
    
    await ref.read(vadNotifierProvider.notifier).stopListening();
    _startUserRecording();
  }

  void _doneSpeaking() {
    ref.read(vadNotifierProvider.notifier).stopListening();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VadState>(vadNotifierProvider, (previous, next) {
      if (next.lastAudioPath != null && previous?.lastAudioPath != next.lastAudioPath) {
        _doneSpeakingWithFile(next.lastAudioPath!);
        ref.read(vadNotifierProvider.notifier).clearAudioPath();
      }
    });

    final vadState = ref.watch(vadNotifierProvider);
    final _isUserRecording = vadState.isRecording;
    final _currentDb = vadState.currentDb;

    if (_isLoading || _reminder == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0C),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPink),
        ),
      );
    }

    final reminder = _reminder!;
    final companionName = reminder.companionName ?? 'AI伴侣';
    final avatarUrl = reminder.companionAvatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 毛玻璃高斯模糊背景
          if (avatarUrl != null && avatarUrl.isNotEmpty)
            Image.network(
              getFullUrl(ref, avatarUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1C1B1F)),
            )
          else
            Container(color: const Color(0xFF1C1B1F)),
          
          Container(
            color: Colors.black.withOpacity(0.75),
          ),
          
          // 模糊层
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 触发毛玻璃
            child: const SizedBox(),
          ).animate().fadeIn(duration: 1.seconds),

          // 右上角模式切换按钮
          if (_isConnected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isContinuousMode = !_isContinuousMode;
                  });
                  SoulToast.info(context, _isContinuousMode ? '已开启顺承对话模式' : '已关闭顺承对话模式');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isContinuousMode 
                        ? AppColors.brandPink.withOpacity(0.2) 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isContinuousMode 
                          ? AppColors.brandPink.withOpacity(0.5) 
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isContinuousMode ? Icons.auto_awesome : Icons.touch_app_outlined,
                        color: _isContinuousMode ? AppColors.brandPink : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isContinuousMode ? '顺承模式: 开' : '顺承模式: 关',
                        style: TextStyle(
                          color: _isContinuousMode ? AppColors.brandPink : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 1.seconds),
            ),

          // 主要通话面板内容
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 顶部状态与伴侣名字
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Text(
                        companionName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 12),
                      Text(
                        _isConnected
                            ? '通话中 ${_formatDuration(_callDurationSeconds)}'
                            : widget.isOutgoing
                                ? '正在呼叫...'
                                : reminder.type == 'WAKE_UP'
                                    ? '来电叫醒中...'
                                    : '日程提醒来电...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),

                // 中间部分：头像与振铃涟漪 (或声波柱)
                _isConnected ? _buildConnectedWave(_isUserRecording, _currentDb) : _buildRingingRipples(avatarUrl),

                // 底部接听/挂断按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
                  child: Row(
                    mainAxisAlignment: (_isConnected || widget.isOutgoing)
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceAround,
                    children: [
                      // 挂断按钮
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _hangup,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x66FF3B30),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (_isConnected || widget.isOutgoing) ? '结束通话' : '拒绝接听',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms),

                      // 接听按钮 (仅振铃状态下显示，且非呼叫中状态)
                      if (!_isConnected && !widget.isOutgoing)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _answer,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x6634C759),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '立刻接听',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 600.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 振铃态：头像 + 多层发光扩散光圈
  Widget _buildRingingRipples(String? avatarUrl) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 涟漪圈 1
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              return Container(
                width: 120 + 130 * _rippleController.value,
                height: 120 + 130 * _rippleController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPink.withOpacity(0.15 * (1 - _rippleController.value)),
                ),
              );
            },
          ),
          // 涟漪圈 2
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              final val = (_rippleController.value + 0.5) % 1.0;
              return Container(
                width: 120 + 130 * val,
                height: 120 + 130 * val,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPink.withOpacity(0.15 * (1 - val)),
                ),
              );
            },
          ),
          // 中央头像
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPink.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(getFullUrl(ref, avatarUrl), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.person, color: Colors.white, size: 54),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 接通态：小头像 + 跳动声波柱 + 状态文本与控制按钮
  Widget _buildConnectedWave(bool isUserRecording, double currentDb) {
    String stateText = '';
    Widget? controlButton;
    
    switch (_callState) {
      case CallSessionState.connecting:
        stateText = '连接中...';
        controlButton = const SizedBox(height: 44);
        break;
      case CallSessionState.speaking:
        stateText = '对方说话中...';
        controlButton = ElevatedButton.icon(
          onPressed: _interrupt,
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
          label: const Text('打断对方', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.withOpacity(0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        );
        break;
      case CallSessionState.listening:
        stateText = isUserRecording ? '正在倾听...' : '等待您的发言...';
        if (_isContinuousMode) {
          controlButton = ElevatedButton.icon(
            onPressed: _doneSpeaking,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('说完了', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
          );
        } else {
          // 非顺承模式：手动触发录音
          controlButton = isUserRecording
              ? ElevatedButton.icon(
                  onPressed: _doneSpeaking,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text('说完了', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _startUserRecording,
                  icon: const Icon(Icons.mic, color: Colors.white),
                  label: const Text('点击说话', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                );
        }
        break;
      case CallSessionState.thinking:
        stateText = '思考中...';
        controlButton = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.brandPink,
          ),
        );
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像过渡缩小
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPink.withOpacity(0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: ClipOval(
            child: _reminder?.companionAvatarUrl != null &&
                    _reminder!.companionAvatarUrl!.isNotEmpty
                ? Image.network(getFullUrl(ref, _reminder!.companionAvatarUrl!), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white, size: 36),
                  ),
          ),
        ).animate().scale(begin: const Offset(1.2, 1.2), end: const Offset(1.0, 1.0), duration: 400.ms),
        
        const SizedBox(height: 30),
        
        // 声波跳动栏 (7根声波柱)
        SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_waveHeights.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 6,
                height: (_callState == CallSessionState.listening || _callState == CallSessionState.speaking) 
                    ? _waveHeights[index] 
                    : 10.0,
                decoration: BoxDecoration(
                  color: AppColors.brandPink,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 20),

        // 状态文本
        Text(
          stateText,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        // 实时环境分贝指示器
        if (_isConnected)
          _buildDbIndicator(currentDb),

        const SizedBox(height: 10),

        // 交互按钮
        SizedBox(
          height: 50,
          child: controlButton,
        ),
      ],
    );
  }

  /// 实时分贝指示器 — 显示当前环境 dB
  Widget _buildDbIndicator(double currentDb) {
    // 将 dBFS 转换为近似的 dBSPL（仅做粗略映射用于用户感知）
    final displayDb = (currentDb + 90.0).clamp(0.0, 120.0);
    
    // 根据分贝级别选择指示颜色
    Color dbColor;
    if (currentDb > -45.0) {
      dbColor = const Color(0xFF4ADE80); // 绿色 = 检测到说话
    } else if (currentDb > -55.0) {
      dbColor = const Color(0xFFFBBF24); // 黄色 = 有声音
    } else {
      dbColor = Colors.white.withValues(alpha: 0.4); // 灰白 = 安静
    }

    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 分贝数值大字显示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Icon(Icons.mic, color: dbColor, size: 16),
            const SizedBox(width: 4),
            Text(
              displayDb.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: dbColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'dB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: dbColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
