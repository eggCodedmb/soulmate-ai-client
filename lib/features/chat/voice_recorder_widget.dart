import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../../core/constants/app_colors.dart';

/// 录音状态
enum VoiceRecordState {
  /// 就绪，等待长按
  ready,

  /// 正在录音
  recording,

  /// 手指滑入取消区域
  canceling,
}

/// 语音录制交互组件
///
/// 提供"长按说话"按钮，长按后弹出录音浮层，
/// 支持上滑取消、松手发送的交互逻辑。
class VoiceRecorderWidget extends StatefulWidget {
  /// 录音完成并发送回调，返回 (音频文件路径, 录音时长毫秒)
  final void Function(String audioPath, int durationMs) onSend;

  /// 取消录音回调
  final VoidCallback? onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  // ==================== 状态 ====================
  VoiceRecordState _state = VoiceRecordState.ready;
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _durationTimer;
  int _recordDurationMs = 0;

  /// 取消区域的全局 Y 坐标阈值（按钮上方 120px 以上视为取消区域）
  double _cancelZoneThreshold = 0;
  bool _cancelZoneCalculated = false;

  // ==================== 动画控制器 ====================
  late final AnimationController _overlayController;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;
  late final AnimationController _buttonScaleController;

  // ==================== 按钮 GlobalKey（用于计算位置） ====================
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonScaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _overlayController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _buttonScaleController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ==================== 录音逻辑 ====================

  Future<void> _startRecording() async {
    try {
      // 检查权限
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请授予麦克风权限')),
          );
        }
        return;
      }

      // 开始录音到临时文件
      final tempDir = Directory.systemTemp;
      final filePath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      setState(() {
        _state = VoiceRecordState.recording;
        _recordDurationMs = 0;
      });

      // 启动动画
      unawaited(_overlayController.forward());
      unawaited(_waveController.repeat());
      unawaited(_pulseController.repeat());

      // 启动计时器
      _durationTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) {
          if (mounted) {
            setState(() => _recordDurationMs += 100);
          }
        },
      );
    } on Exception catch (e) {
      debugPrint('开始录音失败: $e');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _durationTimer?.cancel();

    final path = await _recorder.stop();

    // 停止动画
    unawaited(_overlayController.reverse());
    _waveController.stop();
    _pulseController.stop();

    setState(() => _state = VoiceRecordState.ready);

    if (send && path != null && _recordDurationMs >= 500) {
      widget.onSend(path, _recordDurationMs);
    } else {
      // 取消或录音太短：删除临时文件
      if (path != null) {
        try {
          await File(path).delete();
        } on Exception {
          // 文件可能已被删除，忽略
        }
      }
      if (!send) {
        widget.onCancel?.call();
      }
    }

    _recordDurationMs = 0;
    _cancelZoneCalculated = false;
  }

  // ==================== 手势处理 ====================

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    _buttonScaleController.animateTo(
      0.92,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
    _calculateCancelZone();
    _startRecording();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    // 获取按钮在全局坐标系中的位置
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;

    final buttonPos = buttonBox.localToGlobal(Offset.zero);
    final fingerGlobalY = buttonPos.dy + details.offsetFromOrigin.dy;

    // 手指上滑超过阈值 → 取消区域
    final isInCancelZone = fingerGlobalY < _cancelZoneThreshold;

    if (isInCancelZone && _state != VoiceRecordState.canceling) {
      HapticFeedback.heavyImpact();
      setState(() => _state = VoiceRecordState.canceling);
    } else if (!isInCancelZone && _state == VoiceRecordState.canceling) {
      HapticFeedback.lightImpact();
      setState(() => _state = VoiceRecordState.recording);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _buttonScaleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
    );

    final isInCancelZone = _state == VoiceRecordState.canceling;
    _stopRecording(send: !isInCancelZone);

    if (isInCancelZone) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _calculateCancelZone() {
    if (_cancelZoneCalculated) return;
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;

    final buttonPos = buttonBox.localToGlobal(Offset.zero);
    // 取消区域：按钮上方 140px
    _cancelZoneThreshold = buttonPos.dy - 140;
    _cancelZoneCalculated = true;
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 录音浮层（在按钮上方弹出）
        _buildRecordingOverlay(isDark),
        // 主按钮
        _buildRecordButton(isDark),
      ],
    );
  }

  // ==================== 录音浮层 ====================

  Widget _buildRecordingOverlay(bool isDark) {
    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, child) {
        final value = _overlayController.value;
        if (value == 0) return const SizedBox.shrink();

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _state == VoiceRecordState.ready
            ? const SizedBox.shrink()
            : _buildOverlayContent(isDark),
      ),
    );
  }

  Widget _buildOverlayContent(bool isDark) {
    final isCanceling = _state == VoiceRecordState.canceling;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isCanceling
                ? Colors.red.withValues(alpha: isDark ? 0.2 : 0.12)
                : (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                    .withValues(alpha: isDark ? 0.85 : 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCanceling
                  ? Colors.red.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: isDark ? 0.08 : 0.5),
              width: isCanceling ? 1.5 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isCanceling
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部：取消提示区域
              _buildCancelIndicator(isCanceling, isDark),
              const SizedBox(height: 16),
              // 中间：录音波形动效
              _buildWaveform(isCanceling, isDark),
              const SizedBox(height: 12),
              // 底部：录音时长
              _buildDurationText(isCanceling, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelIndicator(bool isCanceling, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isCanceling
            ? Colors.red.withValues(alpha: 0.15)
            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isCanceling
                  ? Icons.close_rounded
                  : Icons.keyboard_arrow_up_rounded,
              key: ValueKey(isCanceling),
              size: 16,
              color: isCanceling
                  ? Colors.red
                  : isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCanceling ? FontWeight.w600 : FontWeight.w500,
              color: isCanceling
                  ? Colors.red
                  : isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.3),
            ),
            child: Text(isCanceling ? '松开取消' : '上滑取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(bool isCanceling, bool isDark) {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, __) {
              return CustomPaint(
                size: const Size(180, 48),
                painter: _WaveformPainter(
                  progress: _waveController.value,
                  pulseProgress: _pulseController.value,
                  isCanceling: isCanceling,
                  isDark: isDark,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDurationText(bool isCanceling, bool isDark) {
    final seconds = _recordDurationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: isCanceling
            ? Colors.red.withValues(alpha: 0.8)
            : isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
      ),
      child: Text(timeStr),
    );
  }

  // ==================== 录音按钮 ====================

  Widget _buildRecordButton(bool isDark) {
    final isRecording =
        _state == VoiceRecordState.recording || _state == VoiceRecordState.canceling;
    final isCanceling = _state == VoiceRecordState.canceling;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      child: AnimatedBuilder(
        animation: _buttonScaleController,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScaleController.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          key: _buttonKey,
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: isCanceling
                ? LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.8),
                      Colors.red.withValues(alpha: 0.6),
                    ],
                  )
                : isRecording
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.brandPink.withValues(alpha: 0.85),
                          const Color(0xFFFF8FA8).withValues(alpha: 0.85),
                        ],
                      )
                    : null,
            color: isCanceling || isRecording
                ? null
                : isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F3F8),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isRecording || isCanceling
                ? [
                    BoxShadow(
                      color: (isCanceling ? Colors.red : AppColors.brandPink)
                          .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isCanceling
                    ? Colors.white
                    : isRecording
                        ? Colors.white
                        : isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isCanceling
                          ? Icons.close_rounded
                          : isRecording
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                      key: ValueKey('$isCanceling$isRecording'),
                      size: 20,
                      color: isCanceling || isRecording
                          ? Colors.white
                          : isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCanceling
                        ? '松开取消'
                        : isRecording
                            ? '松开发送'
                            : '长按说话',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 波形画笔 ====================

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double pulseProgress;
  final bool isCanceling;
  final bool isDark;

  _WaveformPainter({
    required this.progress,
    required this.pulseProgress,
    required this.isCanceling,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 24;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.42;

    final baseColor = isCanceling
        ? Colors.red
        : AppColors.brandPink;

    for (var i = 0; i < barCount; i++) {
      // 每根柱子有不同的相位偏移，模拟自然波形
      final phase = i * 0.35;
      final wave1 = sin(progress * 2 * pi + phase);
      final wave2 = sin(progress * 4 * pi + phase * 1.5) * 0.5;
      final wave3 = sin(pulseProgress * 2 * pi + i * 0.2) * 0.3;

      final amplitude = (wave1 + wave2 + wave3).abs().clamp(0.15, 1.0);
      final barHeight = maxBarHeight * amplitude;

      // 中间高两边低的包络
      final envelopeFactor =
          1.0 - ((i - barCount / 2).abs() / (barCount / 2)) * 0.5;
      final finalHeight = barHeight * envelopeFactor;

      final x = i * barWidth + barWidth * 0.25;
      final width = barWidth * 0.5;

      // 颜色渐变：中间更亮
      final colorFactor = envelopeFactor;
      final color = baseColor.withValues(
        alpha: (isDark ? 0.5 : 0.35) * colorFactor + 0.15,
      );

      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width;

      canvas.drawLine(
        Offset(x + width / 2, centerY - finalHeight / 2),
        Offset(x + width / 2, centerY + finalHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.isCanceling != isCanceling;
  }
}
