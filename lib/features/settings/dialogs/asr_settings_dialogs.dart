import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/local_storage.dart';
import '../widgets/setting_tiles.dart';

/// ASR 提供商选项
const _asrProviders = [
  {
    'value': 'system',
    'title': '系统默认',
    'subtitle': '使用后端内置的语音识别服务',
    'icon': Icons.dns_outlined,
  },
  {
    'value': 'sherpa_onnx',
    'title': 'Sherpa ONNX (离线)',
    'subtitle': '使用本地 SenseVoice 模型进行离线语音识别',
    'icon': Icons.offline_bolt_rounded,
  },
  {
    'value': 'mimo',
    'title': 'Xiaomi MiMo',
    'subtitle': '小米云端 ASR 服务（mimo-v2.5-asr）',
    'icon': Icons.auto_awesome_rounded,
  },
  {
    'value': 'custom',
    'title': '自定义接入',
    'subtitle': '接入第三方 ASR 服务（OpenAI Whisper API 格式）',
    'icon': Icons.cloud_queue_rounded,
  },
];

/// ASR 提供商选择弹窗
void showAsrProviderDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final current = LocalStorage.asrProviderType;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '选择 ASR 服务商',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_asrProviders.length, (i) {
            final p = _asrProviders[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _asrProviders.length - 1 ? 12 : 0,
              ),
              child: _buildAsrProviderOption(
                context,
                icon: p['icon'] as IconData,
                title: p['title'] as String,
                subtitle: p['subtitle'] as String,
                value: p['value'] as String,
                isSelected: current == p['value'],
                isDark: isDark,
                onSaved: onSaved,
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

Widget _buildAsrProviderOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required String value,
  required bool isSelected,
  required bool isDark,
  required VoidCallback onSaved,
}) {
  return GestureDetector(
    onTap: () async {
      HapticFeedback.lightImpact();
      await LocalStorage.setAsrProviderType(value);
      if (context.mounted) {
        Navigator.pop(context);
      }
      onSaved();
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF009688).withOpacity(isDark ? 0.15 : 0.08)
            : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF009688)
              : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF009688).withOpacity(isDark ? 0.2 : 0.1)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF009688)
                  : isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF009688),
              size: 24,
            ),
        ],
      ),
    ),
  );
}

/// ASR 服务器地址弹窗
void showAsrUrlDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrBaseUrl ?? '');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ASR 服务器地址',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '填写 ASR 服务的 Base URL（不含路径）',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: LocalStorage.asrProviderType == 'mimo'
                  ? 'MiMo API 地址'
                  : 'Base URL',
              hintText: LocalStorage.asrProviderType == 'mimo'
                  ? 'https://token-plan-sgp.xiaomimimo.com/v1'
                  : 'https://api.groq.com',
              prefixIcon: Icons.dns_outlined,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await LocalStorage.setAsrBaseUrl(controller.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  onSaved();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// ASR API Key 弹窗
void showAsrApiKeyDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrApiKey ?? '');
  bool obscure = true;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ASR API Key',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '用于鉴权第三方 ASR 服务',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SettingTextField(
                controller: controller,
                labelText: 'API Key',
                hintText: 'sk-...',
                prefixIcon: Icons.vpn_key_outlined,
                obscureText: obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    setSheetState(() => obscure = !obscure);
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await LocalStorage.setAsrApiKey(controller.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// ASR 模型名称弹窗
void showAsrModelDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: LocalStorage.asrModel);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ASR 模型名称',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '指定用于语音识别的模型',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SettingTextField(
              controller: controller,
              labelText: '模型名称',
              hintText: LocalStorage.asrProviderType == 'mimo'
                  ? 'mimo-v2.5-asr'
                  : 'whisper-large-v3-turbo',
              prefixIcon: Icons.smart_toy_outlined,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await LocalStorage.setAsrModel(controller.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  onSaved();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// VAD 参数调优弹窗
void showVadSettingsDialog(BuildContext context, {required VoidCallback onSaved}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // 临时状态值
  double threshold = LocalStorage.vadThreshold;
  double minSilence = LocalStorage.vadMinSilenceDuration;
  double minSpeech = LocalStorage.vadMinSpeechDuration;
  double noiseGate = LocalStorage.vadNoiseGateThreshold;
  String vadVersion = LocalStorage.vadModelVersion;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部拖拽条
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 标题栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VAD 语音活动检测调优',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          threshold = 0.65;
                          minSilence = 1.2;
                          minSpeech = 0.25;
                          noiseGate = -42.0;
                          vadVersion = 'v4';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF009688)),
                      label: const Text(
                        '恢复默认',
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '微调本地语音活动检测模型以适配不同的录音与环境噪音',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // VAD 模型版本选择
                Text(
                  'VAD 模型版本',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildVadVersionCard(
                        title: 'Silero v4',
                        subtitle: '默认 · 稳定通用',
                        isSelected: vadVersion == 'v4',
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => vadVersion = 'v4');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVadVersionCard(
                        title: 'Silero v5',
                        subtitle: '抗噪增强 · 需下载',
                        isSelected: vadVersion == 'v5',
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => vadVersion = 'v5');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. 人声判定阈值 (Threshold)
                _buildSliderSection(
                  title: '人声判定置信度阈值',
                  value: threshold,
                  valueText: threshold.toStringAsFixed(2),
                  min: 0.1,
                  max: 0.9,
                  divisions: 16,
                  desc: '数值越高越不容易被噪音误触发（但需要大声说），数值越低越灵敏。',
                  isDark: isDark,
                  onChanged: (val) => setState(() => threshold = val),
                ),
                const SizedBox(height: 16),

                // 2. 静音判定时长 (Min Silence Duration)
                _buildSliderSection(
                  title: '说话完静音判定时长',
                  value: minSilence,
                  valueText: '${minSilence.toStringAsFixed(1)} 秒',
                  min: 0.3,
                  max: 2.0,
                  divisions: 34,
                  desc: '停止说话后所需安静时间。时间短响应快，但太短会在稍作停顿时被切断。',
                  isDark: isDark,
                  onChanged: (val) => setState(() => minSilence = val),
                ),
                const SizedBox(height: 16),

                // 3. 最小说话时长 (Min Speech Duration)
                _buildSliderSection(
                  title: '有效说话的最小时长',
                  value: minSpeech,
                  valueText: '${minSpeech.toStringAsFixed(2)} 秒',
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  desc: '声音持续多久才被视为说话，设置较低（如0.15秒）可以防止漏掉“好”、“对”等短词。',
                  isDark: isDark,
                  onChanged: (val) => setState(() => minSpeech = val),
                ),
                const SizedBox(height: 16),

                // 4. 噪声过滤门限 (Noise Gate)
                _buildSliderSection(
                  title: '背景噪声过滤门限',
                  value: noiseGate,
                  valueText: '${noiseGate.toStringAsFixed(0)} dBFS',
                  min: -80.0,
                  max: -20.0,
                  divisions: 60,
                  desc: '低于此音量的声音将被强制静音。如果周围有强力风扇或空调声，调高该值。',
                  isDark: isDark,
                  onChanged: (val) => setState(() => noiseGate = val),
                ),
                const SizedBox(height: 28),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await LocalStorage.setVadThreshold(threshold);
                      await LocalStorage.setVadMinSilenceDuration(minSilence);
                      await LocalStorage.setVadMinSpeechDuration(minSpeech);
                      await LocalStorage.setVadNoiseGateThreshold(noiseGate);
                      await LocalStorage.setVadModelVersion(vadVersion);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      onSaved();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '应用并保存',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildSliderSection({
  required String title,
  required double value,
  required String valueText,
  required double min,
  required double max,
  required int divisions,
  required String desc,
  required bool isDark,
  required ValueChanged<double> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(
              color: Color(0xFF009688),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: const Color(0xFF009688),
          inactiveTrackColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          thumbColor: const Color(0xFF009688),
          overlayColor: const Color(0xFF009688).withOpacity(0.12),
          valueIndicatorColor: const Color(0xFF009688),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          desc,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ),
    ],
  );
}

Widget _buildVadVersionCard({
  required String title,
  required String subtitle,
  required bool isSelected,
  required bool isDark,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF009688).withOpacity(isDark ? 0.15 : 0.08)
            : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF009688)
              : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF009688)
                  : (isDark ? Colors.white : Colors.black),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}
