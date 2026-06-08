import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/network/tts_api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/reminder.dart';
import '../../shared/models/tts_config.dart';
import 'tts_audio_service.dart';

class IncomingCallPage extends ConsumerStatefulWidget {
  final int reminderId;
  final Reminder? reminder;

  const IncomingCallPage({
    super.key,
    required this.reminderId,
    this.reminder,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with TickerProviderStateMixin {
  
  Reminder? _reminder;
  bool _isLoading = false;
  bool _isConnected = false;
  
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _speechPlayer = AudioPlayer();
  
  // 振铃动效 Controller
  late AnimationController _rippleController;
  // 声波跳动 Controller
  late AnimationController _waveController;
  final List<double> _waveHeights = List.filled(7, 10.0);
  final math.Random _random = math.Random();

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
          setState(() {
            for (int i = 0; i < _waveHeights.length; i++) {
              // 随机生成声波高度，模拟说话起伏
              _waveHeights[i] = 10.0 + _random.nextDouble() * 50.0;
            }
          });
        }
      });

    _initRingtoneAndLoad();
  }

  Future<void> _initRingtoneAndLoad() async {
    // 播放振铃（循环播放本地电话铃声）
    try {
      await _ringtonePlayer.setAsset('assets/audio/phone_ringtone.wav');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      _ringtonePlayer.play();
    } catch (e) {
      debugPrint('播放铃声失败: $e');
    }

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
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _waveController.dispose();
    _ringtonePlayer.dispose();
    _speechPlayer.dispose();
    super.dispose();
  }

  // 挂断
  void _hangup() {
    HapticFeedback.mediumImpact();
    _ringtonePlayer.stop();
    _speechPlayer.stop();
    context.pop();
  }

  // 接听
  Future<void> _answer() async {
    HapticFeedback.heavyImpact();
    _ringtonePlayer.stop();
    _rippleController.stop();

    setState(() {
      _isConnected = true;
    });

    _waveController.repeat(reverse: true);
    
    // 开始朗读决策流
    await _startSpeechPlay();
  }

  Future<void> _startSpeechPlay() async {
    final reminder = _reminder;
    if (reminder == null) {
      debugPrint('[IncomingCall] _reminder 为空，无法播放');
      _hangup();
      return;
    }

    final isMimo = LocalStorage.ttsProviderType == 'mimo';
    final ext = isMimo ? 'wav' : 'mp3';

    // 1. 本地缓存优先
    try {
      final supportDir = await getApplicationSupportDirectory();
      final cacheFile = File('${supportDir.path}/reminder_audio_cache/reminder_${reminder.id}.$ext');

      debugPrint('[IncomingCall] 检查本地缓存: ${cacheFile.path}');
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        debugPrint('[IncomingCall] 命中本地预缓存 (${fileSize}B)，开始播放');
        if (fileSize > 0) {
          await _playSpeech(cacheFile.path, isLocal: true);
          return;
        }
        debugPrint('[IncomingCall] 缓存文件为空，跳过');
      } else {
        debugPrint('[IncomingCall] 本地缓存不存在');
      }
    } catch (e) {
      debugPrint('[IncomingCall] 读取本地缓存异常: $e');
    }

    // 2. 线上合成兜底
    debugPrint('[IncomingCall] 尝试线上即时合成...');
    try {
      final apiService = ref.read(apiServiceProvider);
      final ttsClient = ref.read(ttsApiProvider);

      debugPrint('[IncomingCall] TTS 已配置: ${ttsClient.isConfigured}, provider: ${LocalStorage.ttsProviderType}');

      final companion = await apiService.getCompanion(reminder.companionId);
      // 优先使用伴侣 TTS 配置，兜底使用全局 TTS 配置
      final config = getEffectiveTtsConfig(companion.ttsConfig);

      debugPrint('[IncomingCall] 伴侣 TTS 配置: profileId=${config?.profileId}, '
          'companionTtsConfig=${companion.ttsConfig != null}, '
          'effectiveProfileId=${config?.profileId}');

      if (config != null && config.profileId != null && ttsClient.isConfigured) {
        final request = buildTtsRequest(config, reminder.textTemplate);
        debugPrint('[IncomingCall] 开始合成: text="${reminder.textTemplate}", profileId=${config.profileId}');
        final bytes = await ttsClient.generate(request);
        debugPrint('[IncomingCall] 合成完成，大小: ${bytes.length}B');

        if (bytes.isEmpty) {
          debugPrint('[IncomingCall] 合成结果为空');
          throw Exception('TTS 合成返回空数据');
        }

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_speech_${reminder.id}.$ext');
        await tempFile.writeAsBytes(bytes);

        debugPrint('[IncomingCall] 临时文件已写入: ${tempFile.path}，开始播放');
        await _playSpeech(tempFile.path, isLocal: true);
        return;
      } else {
        debugPrint('[IncomingCall] 线上合成条件不满足: '
            'config=${config != null}, profileId=${config?.profileId}, '
            'ttsConfigured=${ttsClient.isConfigured}');
      }
    } catch (e, stackTrace) {
      debugPrint('[IncomingCall] 线上即时合成失败: $e');
      debugPrint('[IncomingCall] 堆栈: $stackTrace');
    }

    // 3. 兜底：无声音但保持通话页面打开，等待用户手动挂断
    debugPrint('[IncomingCall] 所有声音播放决策全部失效，保持通话等待用户手动挂断');
  }

  Future<void> _playSpeech(String source, {required bool isLocal}) async {
    debugPrint('[IncomingCall] _playSpeech: source=$source, isLocal=$isLocal');
    if (isLocal) {
      await _speechPlayer.setFilePath(source);
    } else {
      await _speechPlayer.setUrl(source);
    }

    // 循环播放，直到用户手动挂断
    await _speechPlayer.setLoopMode(LoopMode.one);
    await _speechPlayer.play();
    debugPrint('[IncomingCall] 语音播放已启动');
  }

  @override
  Widget build(BuildContext context) {
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
                            ? '通话中...'
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
                _isConnected ? _buildConnectedWave() : _buildRingingRipples(avatarUrl),

                // 底部接听/挂断按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
                  child: Row(
                    mainAxisAlignment: _isConnected
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
                            _isConnected ? '结束通话' : '拒绝接听',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms),

                      // 接听按钮 (仅振铃状态下显示)
                      if (!_isConnected)
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

  // 接通态：小头像 + 跳动声波柱
  Widget _buildConnectedWave() {
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
        
        const SizedBox(height: 60),
        
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
                height: _waveHeights[index],
                decoration: BoxDecoration(
                  color: AppColors.brandPink,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
