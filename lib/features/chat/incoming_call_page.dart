import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' hide Codec;
import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/network/asr_api_client.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/services/vad_service.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../shared/models/companion.dart';
import '../../shared/widgets/soul_toast.dart';
import 'tts_audio_service.dart';

/// 通话会话状态
enum CallSessionState {
  connecting,
  speaking,
  listening,
  thinking,
}

/// 实时字幕条目
class CallSubtitleItem {
  final String id;
  final String sender;
  String text;
  final bool isUser;
  final DateTime timestamp;

  CallSubtitleItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 通话页面（仿豆包 / 通义千问 沉浸式语音通话模式）
class IncomingCallPage extends ConsumerStatefulWidget {
  final int companionId;
  final Companion? companion;
  final bool isOutgoing;
  final int? conversationId;

  const IncomingCallPage({
    super.key,
    required this.companionId,
    this.companion,
    this.isOutgoing = false,
    this.conversationId,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with TickerProviderStateMixin {
  int? _resolvedConversationId;
  Companion? _companion;
  bool _isLoading = false;
  bool _isConnected = false;

  // 通话控制状态
  CallSessionState _callState = CallSessionState.connecting;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _showSubtitles = true; // 是否显示实时字幕卡片
  bool _isPushToTalkMode = false; // false: 全双工自动倾听(豆包/千问模式); true: 按住说话模式
  bool _isHoldingPushToTalk = false;

  WebSocketChannel? _channel;
  late final TtsAudioService _ttsAudioService;
  final AudioRecorder _recorder = AudioRecorder();
  AudioSession? _audioSession;

  // 实时字幕与流式对话
  final List<CallSubtitleItem> _subtitles = [];
  final ScrollController _subtitleScrollController = ScrollController();
  CallSubtitleItem? _currentAiSubtitleItem;

  int _messageIndex = 0;
  Future<void>? _ttsTaskChain;
  bool _isStreamDone = true;
  int _pendingTtsCount = 0;

  bool _isBackgroundGreetingSent = false;
  final List<String> _pendingAudioPaths = [];

  // 铃声播放
  final FlutterSoundPlayer _ringtonePlayer = FlutterSoundPlayer();
  bool _isPlayingRingtone = false;

  // 动画控制器
  late AnimationController _rippleController;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  final List<double> _waveHeights = List.filled(9, 12.0);
  final math.Random _random = math.Random();

  // 通话时长
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // 自动打断 (Barge-in) 计数与防抖
  int _bargeInLoudFrameCount = 0;

  @override
  void initState() {
    super.initState();
    _ringtonePlayer.openPlayer().then((_) {
      debugPrint('[IncomingCall] Ringtone player opened successfully');
    }).catchError((e) {
      debugPrint('[IncomingCall] Failed to open ringtone player: $e');
    });

    _companion = widget.companion;
    _resolvedConversationId = widget.conversationId;

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_updateWaveformHeights);

    // 初始化 TTS 音频服务
    _ttsAudioService = setOnStateChangedCallback();

    // 如果使用本地离线 ASR，异步预热 Sherpa-ONNX 识别器模型
    if (LocalStorage.asrProviderType == 'sherpa_onnx') {
      SherpaOnnxAsrService.getRecognizer().catchError((e) {
        debugPrint('[IncomingCall] 预热 ASR 识别器提醒: $e');
        return null;
      });
    }

    _initRingtoneAndLoad();
  }

  void _updateWaveformHeights() {
    if (!mounted || !_isConnected) return;

    if (_callState == CallSessionState.speaking) {
      // AI 说话时：由 TTS 播放状态和随机波动驱动波形
      final isPlaying = _ttsAudioService.isPlaying;
      setState(() {
        for (int i = 0; i < _waveHeights.length; i++) {
          if (isPlaying) {
            final base = 18.0 + _random.nextDouble() * 42.0;
            final distFromCenter =
                (i - _waveHeights.length / 2).abs() / (_waveHeights.length / 2);
            _waveHeights[i] = base * (1.0 - distFromCenter * 0.35);
          } else {
            _waveHeights[i] = 12.0;
          }
        }
      });
    } else if (_callState != CallSessionState.listening) {
      // connecting / thinking
      setState(() {
        for (int i = 0; i < _waveHeights.length; i++) {
          _waveHeights[i] = 12.0;
        }
      });
    }
  }

  /// 提取 TTS 状态回调逻辑以便复用
  TtsAudioService setOnStateChangedCallback() {
    final service = TtsAudioService(ref.read(ttsApiProvider));
    service.setOnStateChanged(() {
      if (!mounted) return;

      final isPlaying = service.isPlaying;
      debugPrint(
          '[IncomingCall] onStateChanged: isPlaying=$isPlaying, callState=$_callState, isStreamDone=$_isStreamDone, pendingTtsCount=$_pendingTtsCount');

      if (isPlaying) {
        if (_callState != CallSessionState.speaking) {
          setState(() {
            _callState = CallSessionState.speaking;
          });
          // AI 说话时，停止麦克风录音，彻底切断扬声器声音回采自打断循环
          _stopUserRecording(send: false);
        }
      } else if (!isPlaying &&
          (_callState == CallSessionState.speaking ||
              _callState == CallSessionState.thinking)) {
        // AI 播放完成或停止，进行统一断句与结束判定
        _checkIfAllDone();
      }
    });
    return service;
  }

  Future<void> _initRingtoneAndLoad() async {
    // 1. 如果尚未加载伴侣数据，先加载
    if (_companion == null) {
      setState(() => _isLoading = true);
      try {
        final apiService = ref.read(apiServiceProvider);
        final comp = await apiService.getCompanion(widget.companionId);
        setState(() {
          _companion = comp;
        });
      } catch (e) {
        debugPrint('获取伴侣信息失败: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }

    // 2. 预接通 WebSocket，提高接通瞬间响应速度
    await _connectWebSocket();

    // 3. 处理呼入/呼出逻辑
    if (!widget.isOutgoing) {
      _startRingtone();
    } else {
      _startRingtone();
      _isBackgroundGreetingSent = true;
      _playInitialGreeting();

      Future.delayed(const Duration(milliseconds: 3200), () {
        if (mounted && !_isConnected) {
          _answer();
        }
      });
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _subtitleScrollController.dispose();
    _rippleController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _stopRingtone();
    _ringtonePlayer.closePlayer();
    _ttsAudioService.dispose();
    _recorder.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // 挂断
  Future<void> _hangup() async {
    HapticFeedback.mediumImpact();
    _stopRingtone();
    _ttsAudioService.stop();

    await ref.read(vadNotifierProvider.notifier).stopListening();

    if (_audioSession != null) {
      await _audioSession!.setActive(false);
    }

    _callTimer?.cancel();
    _channel?.sink.close();
    if (mounted) {
      context.pop();
    }
  }

  // 接听
  Future<void> _answer() async {
    HapticFeedback.heavyImpact();
    _stopRingtone();
    _rippleController.stop();

    // 配置音频会话为 VoIP 通话模式（回声消除 + 扬声器 + 同时录放）
    _audioSession = await AudioSession.instance;
    final avOptions = _isSpeakerOn
        ? (AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp)
        : (AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp);

    await _audioSession!.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: avOptions,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    await _audioSession!.setActive(true);

    setState(() {
      _isConnected = true;
      _callState = CallSessionState.connecting;
    });

    _waveController.repeat(reverse: true);
    _startCallTimer();
    await _connectWebSocket();

    if (!_isBackgroundGreetingSent) {
      await _playInitialGreeting();
    } else {
      if (_pendingAudioPaths.isNotEmpty) {
        setState(() {
          _callState = CallSessionState.speaking;
        });
        for (int i = 0; i < _pendingAudioPaths.length; i++) {
          await _ttsAudioService.enqueue(
              _pendingAudioPaths[i], 'call_msg_bg_$i');
        }
        _pendingAudioPaths.clear();
      } else {
        setState(() {
          _callState = CallSessionState.thinking;
        });
      }
    }

    // 默认接通后在非静音且全双工模式下自动开启麦克风监听
    if (!_isMuted && !_isPushToTalkMode) {
      _startUserRecording();
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
    if (_channel != null) return;
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
        final audioBase64 = json['audio'] as String?;
        final content = json['content'] as String?;
        final done = json['done'] as bool? ?? false;
        final error = json['error'] as String?;
        final conversationId = json['conversationId'] as int?;

        if (conversationId != null && _resolvedConversationId == null) {
          setState(() {
            _resolvedConversationId = conversationId;
          });
        }

        if (error != null) {
          debugPrint('[IncomingCall] 服务端返回错误: $error');
          if (mounted) {
            SoulToast.error(context, error);
          }
          _isStreamDone = true;
          _checkIfAllDone();
          return;
        }

        if (done) {
          _isStreamDone = true;
        }

        // 更新实时字幕
        if (content != null && content.isNotEmpty) {
          _appendAiSubtitleContent(content);
        }

        if (audioBase64 != null && audioBase64.isNotEmpty) {
          _pendingTtsCount++;
          final index = _messageIndex;
          _ttsTaskChain = (_ttsTaskChain ?? Future.value()).then((_) async {
            try {
              final bytes = base64Decode(audioBase64);
              final tempDir = await getTemporaryDirectory();
              final key = md5.convert(bytes).toString();
              final file = File('${tempDir.path}/tts_cache/$key.wav');
              if (!await file.parent.exists()) {
                await file.parent.create(recursive: true);
              }
              await file.writeAsBytes(bytes);

              if (mounted) {
                if (_isConnected) {
                  await _ttsAudioService.enqueue(
                      file.path, 'call_msg_$index');
                } else {
                  _pendingAudioPaths.add(file.path);
                }
              }
            } finally {
              if (index == _messageIndex) {
                _pendingTtsCount--;
                _checkIfAllDone();
              }
            }
          }).catchError((Object e) {
            debugPrint('[IncomingCall] 播放音频错误: $e');
          });
        } else if (done) {
          _checkIfAllDone();
        }
      } else if (action == 'interrupt-ack') {
        debugPrint('[IncomingCall] 收到打断 ACK 确认');
      }
    } catch (e) {
      debugPrint('[IncomingCall] 解析 WebSocket 消息异常: $e');
    }
  }

  void _appendAiSubtitleContent(String textChunk) {
    if (!mounted) return;
    final companionName = _companion?.name ?? 'AI伴侣';
    setState(() {
      if (_currentAiSubtitleItem == null ||
          _subtitles.isEmpty ||
          _subtitles.last.isUser) {
        _currentAiSubtitleItem = CallSubtitleItem(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: companionName,
          text: textChunk,
          isUser: false,
        );
        _subtitles.add(_currentAiSubtitleItem!);
      } else {
        _currentAiSubtitleItem!.text += textChunk;
      }
    });

    _scrollToBottomSubtitles();
  }

  void _addUserSubtitleContent(String text) {
    if (!mounted) return;
    setState(() {
      _subtitles.add(CallSubtitleItem(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: '我',
        text: text,
        isUser: true,
      ));
      _currentAiSubtitleItem = null;
    });

    _scrollToBottomSubtitles();
  }

  void _scrollToBottomSubtitles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subtitleScrollController.hasClients) {
        _subtitleScrollController.animateTo(
          _subtitleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onWebSocketDone() {
    debugPrint('[IncomingCall] WebSocket 连接关闭');
    if (!_isStreamDone) {
      _isStreamDone = true;
      _checkIfAllDone();
    }
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('[IncomingCall] WebSocket 错误: $error');
    if (!_isStreamDone) {
      _isStreamDone = true;
      _checkIfAllDone();
    }
  }

  void _checkIfAllDone() {
    if (!mounted) return;
    final isPlaying = _ttsAudioService.isPlaying;
    final processingState = _ttsAudioService.processingState;
    final isDonePlaying = processingState == ProcessingState.completed ||
        processingState == ProcessingState.idle;

    debugPrint(
        '[IncomingCall] _checkIfAllDone: isStreamDone=$_isStreamDone, pendingTtsCount=$_pendingTtsCount, isPlaying=$isPlaying, processingState=$processingState, callState=$_callState');

    if (_isStreamDone &&
        _pendingTtsCount == 0 &&
        isDonePlaying &&
        (_callState == CallSessionState.speaking ||
            _callState == CallSessionState.thinking)) {
      debugPrint('[IncomingCall] 所有 TTS 任务及播放均已完成，自动切换回听状态');
      setState(() {
        _callState = CallSessionState.listening;
      });

      // 仅在全双工自动模式且非静音时，确保麦克风开起
      if (!_isPushToTalkMode && !_isMuted) {
        _startUserRecording();
      }
    }
  }

  Future<void> _playInitialGreeting() async {
    while (_isLoading && _companion == null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final companionId = _companion?.id ?? widget.companionId;

    debugPrint('[IncomingCall] 向 AI 发送 [GREETING] 指令以动态生成开场白...');

    setState(() {
      _callState = CallSessionState.thinking;
    });

    if (_channel != null) {
      final payload = {
        'action': 'speak',
        'companionId': companionId,
        'conversationId':
            _resolvedConversationId ?? widget.conversationId ?? 0,
        'content': '[GREETING]',
      };
      _isStreamDone = false;
      _channel!.sink.add(jsonEncode(payload));
    } else {
      setState(() {
        _callState = CallSessionState.listening;
      });
      if (!_isMuted && !_isPushToTalkMode) {
        _startUserRecording();
      }
    }
  }

  Future<void> _startUserRecording() async {
    if (_isMuted) return;
    final vadState = ref.read(vadNotifierProvider);
    if (vadState.isRecording) return;

    try {
      if (!await _recorder.hasPermission()) {
        debugPrint('[IncomingCall] 录音权限未授予');
        return;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
      );

      await ref.read(vadNotifierProvider.notifier).startListening(stream);
    } catch (e) {
      debugPrint('[IncomingCall] VAD 开始录音失败: $e');
    }
  }

  Future<void> _stopUserRecording({required bool send}) async {
    await ref.read(vadNotifierProvider.notifier).stopListening();
    await _recorder.stop();
  }

  void _doneSpeakingWithFile(String path) {
    _processAndSendUserVoice(path);
  }

  Future<void> _processAndSendUserVoice(String path) async {
    if (!mounted) return;

    setState(() {
      _callState = CallSessionState.thinking;
    });

    try {
      // 执行 ASR 识别（客户端本地 sherpa_onnx / 线上 mimo / custom / system）
      final String transcribedText;
      if (LocalStorage.asrProviderType == 'system') {
        final apiService = ref.read(apiServiceProvider);
        transcribedText = await apiService.transcribeAudio(path);
      } else {
        final asrClient = AsrApiClient();
        transcribedText = await asrClient.transcribe(path);
      }

      // 识别完成后清理临时录音文件
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      if (!mounted) return;

      final text = transcribedText.trim();
      if (text.isEmpty) {
        debugPrint('[IncomingCall] ASR 未识别出有效文本，忽略并恢复倾听');
        setState(() {
          _callState = CallSessionState.listening;
        });
        if (!_isMuted && !_isPushToTalkMode) {
          _startUserRecording();
        }
        return;
      }

      // 将 ASR 识别结果渲染在实时字幕上
      _addUserSubtitleContent(text);

      _messageIndex++;
      _pendingTtsCount = 0;
      _currentAiSubtitleItem = null;

      if (_channel != null) {
        final payload = {
          'action': 'speak',
          'companionId': _companion?.id ?? widget.companionId,
          'conversationId':
              _resolvedConversationId ?? widget.conversationId ?? 0,
          'content': text,
        };
        _isStreamDone = false;
        _channel!.sink.add(jsonEncode(payload));
      } else {
        debugPrint('[IncomingCall] WebSocket 未连接，无法发送消息');
        setState(() {
          _callState = CallSessionState.listening;
        });
        if (!_isMuted && !_isPushToTalkMode) {
          _startUserRecording();
        }
      }
    } catch (e) {
      debugPrint('[IncomingCall] 语音 ASR 识别或发送异常: $e');
      if (mounted) {
        SoulToast.error(context, '语音识别失败: $e');
        setState(() {
          _callState = CallSessionState.listening;
        });
        if (!_isMuted && !_isPushToTalkMode) {
          _startUserRecording();
        }
      }
    }
  }

  /// 抢断/打断逻辑 (Barge-in)
  Future<void> _interrupt() async {
    HapticFeedback.mediumImpact();
    if (_channel != null) {
      final payload = {
        'action': 'interrupt',
        'conversationId':
            _resolvedConversationId ?? widget.conversationId ?? 0,
      };
      _channel!.sink.add(jsonEncode(payload));
    }

    // 立即停止本地 TTS 播放并清理缓存
    await _ttsAudioService.stop();
    _ttsTaskChain = null;
    _isStreamDone = true;
    _pendingTtsCount = 0;
    _messageIndex++;
    _currentAiSubtitleItem = null;

    setState(() {
      _callState = CallSessionState.listening;
    });

    await ref.read(vadNotifierProvider.notifier).stopListening();
    if (!_isMuted && !_isPushToTalkMode) {
      _startUserRecording();
    }
  }

  // 控制功能：切换静音
  Future<void> _toggleMute() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      await _stopUserRecording(send: false);
      SoulToast.info(context, '麦克风已静音');
    } else {
      if (_callState == CallSessionState.listening && !_isPushToTalkMode) {
        _startUserRecording();
      }
      SoulToast.info(context, '麦克风已取消静音');
    }
  }

  // 控制功能：切换扬声器/听筒
  Future<void> _toggleSpeaker() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });

    if (_audioSession != null) {
      final avOptions = _isSpeakerOn
          ? (AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp)
          : (AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp);

      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: avOptions,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
    }
    SoulToast.info(context, _isSpeakerOn ? '已切换至免提扬声器' : '已切换至听筒模式');
  }

  // 控制功能：切换全双工/按住说话
  void _togglePushToTalkMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPushToTalkMode = !_isPushToTalkMode;
    });

    if (_isPushToTalkMode) {
      _stopUserRecording(send: false);
      SoulToast.info(context, '已切换至「按住说话」模式');
    } else {
      if (_callState == CallSessionState.listening && !_isMuted) {
        _startUserRecording();
      }
      SoulToast.info(context, '已切换至「自由交谈」模式');
    }
  }

  // 按住说话手势处理
  void _onPushToTalkStart(LongPressStartDetails details) {
    if (_isMuted) {
      SoulToast.info(context, '请先解除静音');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isHoldingPushToTalk = true;
    });
    if (_callState == CallSessionState.speaking) {
      _interrupt();
    } else {
      _startUserRecording();
    }
  }

  void _onPushToTalkEnd(LongPressEndDetails details) {
    if (!_isHoldingPushToTalk) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isHoldingPushToTalk = false;
    });
    ref.read(vadNotifierProvider.notifier).stopListening();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VadState>(vadNotifierProvider, (previous, next) {
      // 处理真正的人声语音分段触发发送
      if (next.lastAudioPath != null &&
          previous?.lastAudioPath != next.lastAudioPath) {
        _doneSpeakingWithFile(next.lastAudioPath!);
        Future.microtask(() {
          if (mounted) {
            ref.read(vadNotifierProvider.notifier).clearAudioPath();
          }
        });
      }
    });

    final vadState = ref.watch(vadNotifierProvider);
    final isUserRecording = vadState.isRecording;
    final currentDb = vadState.currentDb;

    if (_isLoading && _companion == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF070709),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPink),
        ),
      );
    }

    final companionName = _companion?.name ?? 'AI伴侣';
    final avatarUrl = _companion?.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 高清磨砂质感背景
          _buildAmbientBackground(avatarUrl),

          // 主布局 View
          SafeArea(
            child: Column(
              children: [
                // 顶栏：伴侣信息与通话计时
                _buildTopHeader(companionName),

                const SizedBox(height: 12),

                // 中间区域：核心伴侣光球 & 动态波形 (占比 35%)
                Expanded(
                  flex: 5,
                  child: Center(
                    child: _isConnected
                        ? _buildConnectedOrb(isUserRecording, currentDb)
                        : _buildRingingOrb(avatarUrl),
                  ),
                ),

                // 中下区域：实时字幕滚屏卡片 (仿豆包/千问字幕)
                if (_isConnected && _showSubtitles)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSubtitleCard(companionName),
                    ),
                  )
                else if (_isConnected)
                  const Spacer(),

                const SizedBox(height: 16),

                // 底部区域：专业全功能控制台
                _buildBottomConsole(avatarUrl),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. 背景沉浸光效
  Widget _buildAmbientBackground(String? avatarUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          Image.network(
            getFullUrl(ref, avatarUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF121216)),
          )
        else
          Container(color: const Color(0xFF121216)),
        Container(
          color: Colors.black.withOpacity(0.82),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  // 2. 顶栏头部信息
  Widget _buildTopHeader(String companionName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70, size: 30),
                onPressed: _hangup,
              ),
              Column(
                children: [
                  Text(
                    companionName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnected
                        ? '通话中 ${_formatDuration(_callDurationSeconds)}'
                        : widget.isOutgoing
                            ? '正在呼叫...'
                            : '邀请来电...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              // 右侧字幕开关
              if (_isConnected)
                IconButton(
                  icon: Icon(
                    _showSubtitles
                        ? Icons.subtitles_rounded
                        : Icons.subtitles_off_outlined,
                    color: _showSubtitles
                        ? AppColors.brandPink
                        : Colors.white.withOpacity(0.5),
                    size: 24,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showSubtitles = !_showSubtitles;
                    });
                    SoulToast.info(context,
                        _showSubtitles ? '已开启实时字幕' : '已隐藏实时字幕');
                  },
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  // 3. 未接通时的振铃光环
  Widget _buildRingingOrb(String? avatarUrl) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              return Container(
                width: 120 + 120 * _rippleController.value,
                height: 120 + 120 * _rippleController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPink
                      .withOpacity(0.2 * (1 - _rippleController.value)),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              final val = (_rippleController.value + 0.5) % 1.0;
              return Container(
                width: 120 + 120 * val,
                height: 120 + 120 * val,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPink.withOpacity(0.2 * (1 - val)),
                ),
              );
            },
          ),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPink.withOpacity(0.6),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(getFullUrl(ref, avatarUrl), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 54),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. 接通后的核心伴侣光球 & 音频声波
  Widget _buildConnectedOrb(bool isUserRecording, double currentDb) {
    String stateTag = '';
    Color glowColor = AppColors.brandPink;

    switch (_callState) {
      case CallSessionState.connecting:
        stateTag = '⚡ 正在建立通话...';
        glowColor = Colors.blueAccent;
        break;
      case CallSessionState.speaking:
        stateTag = '🔊 AI 正在说话...';
        glowColor = AppColors.brandPink;
        break;
      case CallSessionState.listening:
        stateTag = isUserRecording ? '🎙️ 正在听你说...' : '👂 随时开口说话...';
        glowColor = const Color(0xFF34C759);
        break;
      case CallSessionState.thinking:
        stateTag = '✨ AI 思考中...';
        glowColor = Colors.orangeAccent;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 呼吸脉冲伴侣头像
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + 0.04 * _pulseController.value;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.55),
                      blurRadius: 30 + 10 * _pulseController.value,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                      color: Colors.white.withOpacity(0.85), width: 2.5),
                ),
                child: ClipOval(
                  child: _companion?.avatarUrl != null &&
                          _companion!.avatarUrl!.isNotEmpty
                      ? Image.network(
                          getFullUrl(ref, _companion!.avatarUrl!),
                          fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 48),
                        ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // 状态 Shimmer 胶囊
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: glowColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glowColor.withOpacity(0.35), width: 1),
          ),
          child: Text(
            stateTag,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: glowColor,
            ),
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 16),

        // 9柱动态声波跳动条
        SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_waveHeights.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 4,
                height: _waveHeights[index],
                decoration: BoxDecoration(
                  color: glowColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // 5. 实时字幕面板（全新设计：采用 Material Icons 标签与精致磨砂卡片）
  Widget _buildSubtitleCard(String companionName) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12131A).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _subtitles.isEmpty
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subtitles_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.35),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '实时字幕记录中...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _subtitleScrollController,
                    itemCount: _subtitles.length,
                    itemBuilder: (context, index) {
                      final item = _subtitles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 身份 Icon 标签（纯 Material Icons，严禁 Emoji）
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.isUser
                                    ? AppColors.brandPink.withOpacity(0.18)
                                    : const Color(0xFF00E5FF).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: item.isUser
                                      ? AppColors.brandPink.withOpacity(0.35)
                                      : const Color(0xFF00E5FF).withOpacity(0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isUser
                                        ? Icons.mic_rounded
                                        : Icons.auto_awesome_rounded,
                                    size: 12,
                                    color: item.isUser
                                        ? AppColors.brandPink
                                        : const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.sender,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: item.isUser
                                          ? AppColors.brandPink
                                          : const Color(0xFF80F3FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 文本内容
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: item.isUser
                                        ? Colors.white.withOpacity(0.88)
                                        : Colors.white,
                                    fontWeight: item.isUser
                                        ? FontWeight.normal
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  // 6. 底部控制台 (静音/免提/打断/挂断/模式切换)
  Widget _buildBottomConsole(String? avatarUrl) {
    if (!_isConnected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: widget.isOutgoing
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceAround,
          children: [
            // 挂断按钮
            _buildCircleIconButton(
              icon: Icons.call_end_rounded,
              color: const Color(0xFFFF3B30),
              label: widget.isOutgoing ? '取消呼叫' : '拒绝',
              onTap: _hangup,
            ),
            if (!widget.isOutgoing)
              _buildCircleIconButton(
                icon: Icons.call_rounded,
                color: const Color(0xFF34C759),
                label: '接听',
                onTap: _answer,
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：快捷功能按钮（静音、扬声器、打断、模式）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 静音按钮
              _buildControlIconButton(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _isMuted ? '已静音' : '静音',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              // 免提按钮
              _buildControlIconButton(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.phone_in_talk_rounded,
                label: _isSpeakerOn ? '扬声器' : '听筒',
                isActive: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
              // 手动打断按钮 (仅 AI 说话中显示)
              if (_callState == CallSessionState.speaking)
                _buildControlIconButton(
                  icon: Icons.stop_circle_outlined,
                  label: '打断对方',
                  isActive: true,
                  activeColor: Colors.orange,
                  onTap: _interrupt,
                )
              else
                _buildControlIconButton(
                  icon: _isPushToTalkMode
                      ? Icons.touch_app_outlined
                      : Icons.auto_awesome_rounded,
                  label: _isPushToTalkMode ? '按住说话' : '自由交谈',
                  isActive: !_isPushToTalkMode,
                  onTap: _togglePushToTalkMode,
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 第二排：主要交互区（挂断 & 按住说话按钮）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPushToTalkMode) ...[
                // 按住说话按钮
                Expanded(
                  child: GestureDetector(
                    onLongPressStart: _onPushToTalkStart,
                    onLongPressEnd: _onPushToTalkEnd,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _isHoldingPushToTalk
                            ? const LinearGradient(
                                colors: [
                                  AppColors.brandPink,
                                  Color(0xFFFF8FA8)
                                ],
                              )
                            : null,
                        color: _isHoldingPushToTalk
                            ? null
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _isHoldingPushToTalk
                              ? AppColors.brandPink
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isHoldingPushToTalk
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isHoldingPushToTalk ? '松开发送' : '按住说话',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // 挂断按钮
              GestureDetector(
                onTap: _hangup,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66FF3B30),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = activeColor ?? AppColors.brandPink;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? color.withOpacity(0.25)
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: isActive
                    ? color.withOpacity(0.6)
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? color : Colors.white.withOpacity(0.7),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? color : Colors.white.withOpacity(0.6),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // 铃声控制逻辑
  Future<void> _startRingtone() async {
    try {
      final byteData = await rootBundle.load('assets/audio/phone_ringtone.wav');
      final buffer = byteData.buffer.asUint8List();
      _isPlayingRingtone = true;
      _playRingtoneLoop(buffer);
    } catch (e) {
      debugPrint('播放铃声失败: $e');
    }
  }

  void _playRingtoneLoop(Uint8List buffer) async {
    if (!_isPlayingRingtone || !mounted) return;
    try {
      await _ringtonePlayer.startPlayer(
        fromDataBuffer: buffer,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          if (_isPlayingRingtone) {
            _playRingtoneLoop(buffer);
          }
        },
      );
    } catch (e) {
      debugPrint('循环播放铃声帧失败: $e');
    }
  }

  Future<void> _stopRingtone() async {
    _isPlayingRingtone = false;
    try {
      await _ringtonePlayer.stopPlayer();
    } catch (_) {}
  }
}
