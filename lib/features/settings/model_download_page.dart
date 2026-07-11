import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/soul_toast.dart';

class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({super.key});

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  final Dio _dio = Dio();
  final Map<String, double> _progress = {};
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _isInstalled = {};
  final Map<String, CancelToken> _cancelTokens = {};

  final List<Map<String, dynamic>> _models = [
    {
      'key': 'silero_vad_v4',
      'name': 'Silero VAD v4 (静音检测)',
      'fileName': 'silero_vad.onnx',
      'size': '4.7 MB',
      'desc': '系统内置的默认语音活动检测模型，能快速判断是否有人在说话。连接稳定，CPU 开销小。',
      'url': 'https://hf-mirror.com/csukuangfj/vad/resolve/main/silero_vad.onnx',
      'mirrorUrl': 'https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
    },
    {
      'key': 'silero_vad_v5',
      'name': 'Silero VAD v5 (抗噪增强版)',
      'fileName': 'silero_vad_v5.onnx',
      'size': '4.7 MB',
      'desc': '最新第 5 代 VAD 检测模型。特别增强了对白噪、街头杂音的过滤能力，断句响应更敏捷。',
      'url': 'https://hf-mirror.com/aufklarer/Silero-VAD-v5-ONNX/resolve/main/silero_vad.onnx',
      'mirrorUrl': 'https://ghfast.top/https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx',
    },
    {
      'key': 'sensevoice_asr',
      'name': 'SenseVoice 离线识别模型',
      'fileName': 'sensevoice.onnx',
      'size': '225.4 MB',
      'desc': '阿里巴巴开源的非流式多语种语音识别大模型。支持中/英/日/韩/粤，离线推理识别率高，速度极快。',
      'url': 'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
      'mirrorUrl': 'https://www.modelscope.cn/models/poloniumrock/SenseVoiceSmallOnnx/resolve/master/model.int8.onnx',
    },
    {
      'key': 'sensevoice_tokens',
      'name': 'SenseVoice 识别词表',
      'fileName': 'sensevoice-tokens.txt',
      'size': '1.2 MB',
      'desc': 'SenseVoice ASR 离线模型专属的词表索引文件，缺失会导致语音识别无法输出汉字。',
      'url': 'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
      'mirrorUrl': 'https://www.modelscope.cn/models/poloniumrock/SenseVoiceSmallOnnx/resolve/master/tokens.txt',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkStatuses();
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('Page disposed');
    }
    _dio.close();
    super.dispose();
  }

  Future<void> _checkStatuses() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    for (final m in _models) {
      final key = m['key'] as String;
      final fileName = m['fileName'] as String;
      final file = File('${modelDir.path}/$fileName');
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _isInstalled[key] = exists;
        });
      }
    }
  }

  Future<void> _downloadModel(Map<String, dynamic> model, bool useMirror) async {
    final key = model['key'] as String;
    final fileName = model['fileName'] as String;
    final primaryUrl = model['url'] as String;
    final mirrorUrl = model['mirrorUrl'] as String;
    final url = (useMirror && mirrorUrl.isNotEmpty) ? mirrorUrl : primaryUrl;

    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/models/$fileName';

    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    if (mounted) {
      setState(() {
        _isDownloading[key] = true;
        _progress[key] = 0.0;
      });
    }

    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progressVal = received / total;
            if (mounted) {
              setState(() {
                _progress[key] = progressVal;
              });
            }
          }
        },
      );

      if (mounted) {
        SoulToast.success(context, '${model['name']} 下载成功');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('Download cancelled: $key');
      } else {
        debugPrint('Download failed: $e');
        if (mounted) {
          SoulToast.error(context, '${model['name']} 下载失败，请检查网络');
        }
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
    } finally {
      _cancelTokens.remove(key);
      if (mounted) {
        setState(() {
          _isDownloading[key] = false;
        });
      }
      _checkStatuses();
    }
  }

  void _cancelDownload(String key) {
    _cancelTokens[key]?.cancel('User cancelled');
    if (mounted) {
      setState(() {
        _isDownloading[key] = false;
        _progress[key] = 0.0;
      });
    }
  }

  Future<void> _deleteModel(Map<String, dynamic> model) async {
    final fileName = model['fileName'] as String;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('是否确认删除 ${model['name']}？这可能会导致对应的语音服务无法离线使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/models/$fileName');
        if (await file.exists()) {
          await file.delete();
        }
        if (mounted) {
          SoulToast.success(context, '删除成功');
        }
      } catch (e) {
        if (mounted) {
          SoulToast.error(context, '删除失败');
        }
      }
      _checkStatuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      appBar: AppBar(
        title: const Text('离线模型管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _models.length,
          itemBuilder: (context, index) {
            final m = _models[index];
            final key = m['key'] as String;
            final isInstalled = _isInstalled[key] ?? false;
            final isDownloading = _isDownloading[key] ?? false;
            final progress = _progress[key] ?? 0.0;

            return _buildModelCard(m, isInstalled, isDownloading, progress, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildModelCard(
    Map<String, dynamic> model,
    bool isInstalled,
    bool isDownloading,
    double progress,
    bool isDark,
  ) {
    final key = model['key'] as String;
    final mirrorUrl = model['mirrorUrl'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：标题与文件大小
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  model['name'] as String,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                model['size'] as String,
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 文件名称指示
          Text(
            '文件名: ${model['fileName']}',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey[500],
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          // 模型描述
          Text(
            model['desc'] as String,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[700],
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // 进度条（仅下载中显示）
          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                color: const Color(0xFF009688),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '下载进度: ${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF009688),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => _cancelDownload(key),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 操作按钮区域
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 安装状态 Tag
              _buildStatusTag(isInstalled, isDownloading, isDark),
              
              // 按钮动作
              Row(
                children: [
                  if (isInstalled) ...[
                    // 已安装：显示删除按钮
                    ElevatedButton.icon(
                      onPressed: () => _deleteModel(model),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('删除'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ] else if (!isDownloading) ...[
                    // 未下载：显示下载按钮
                    if (mirrorUrl.isNotEmpty) ...[
                      OutlinedButton(
                        onPressed: () => _downloadModel(model, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('备用源'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _downloadModel(model, mirrorUrl.isNotEmpty),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('下载'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(bool isInstalled, bool isDownloading, bool isDark) {
    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF009688).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '正在下载',
          style: TextStyle(
            color: Color(0xFF009688),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '已部署',
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '未部署',
        style: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
