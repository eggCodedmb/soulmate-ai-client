import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_service.dart';
import '../../core/services/reminder_scheduler_service.dart';
import '../../shared/models/reminder.dart';
import '../../shared/models/companion.dart';

class ReminderEditPage extends ConsumerStatefulWidget {
  final Reminder? reminder;

  const ReminderEditPage({super.key, this.reminder});

  @override
  ConsumerState<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends ConsumerState<ReminderEditPage> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  List<Companion> _companions = [];
  
  int? _selectedCompanionId;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final List<int> _selectedDays = []; // 1=Mon, 7=Sun
  final TextEditingController _templateController = TextEditingController();
  String _selectedType = 'WAKE_UP'; // WAKE_UP or NOTIFICATION
  bool _enabled = true;

  final List<Map<String, String>> _quickTemplates = [
    {
      'label': '清晨叫醒',
      'type': 'WAKE_UP',
      'text': '早上好呀，大懒猪快起床啦。今天又是充满希望的一天，记得要开心哦，我一直在想你呢。'
    },
    {
      'label': '备忘提醒',
      'type': 'NOTIFICATION',
      'text': '新的一天也要加油哦！别忘了我们晚上的约定，我会一直等你的。'
    },
    {
      'label': '晚安叮嘱',
      'type': 'NOTIFICATION',
      'text': '夜深啦，小宝贝该睡觉了哦，盖好被子，做个好梦，我在梦里等你。'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanions();
    
    if (widget.reminder != null) {
      final r = widget.reminder!;
      _selectedCompanionId = r.companionId;
      _selectedType = r.type;
      _enabled = r.enabled == 1;
      _templateController.text = r.textTemplate;
      
      // 解析时间
      final parts = r.reminderTime.split(':');
      if (parts.length == 2) {
        final hr = int.tryParse(parts[0]);
        final min = int.tryParse(parts[1]);
        if (hr != null && min != null) {
          _selectedTime = TimeOfDay(hour: hr, minute: min);
        }
      }
      
      // 解析重复星期
      if (r.repeatDays.isNotEmpty) {
        final days = r.repeatDays.split(',');
        for (final d in days) {
          final val = int.tryParse(d);
          if (val != null) {
            _selectedDays.add(val);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanions() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final list = await apiService.getCompanionList();
      setState(() {
        _companions = list;
        // 如果没有选中伴侣，且列表不为空，默认选第一个
        if (_selectedCompanionId == null && list.isNotEmpty) {
          _selectedCompanionId = list.first.id;
        }
      });
    } catch (e) {
      debugPrint('获取伴侣列表失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brandPink,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _selectedDays.sort();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompanionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择呼叫伴侣')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final apiService = ref.read(apiServiceProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final hr = _selectedTime.hour.toString().padLeft(2, '0');
    final min = _selectedTime.minute.toString().padLeft(2, '0');
    final reminderTime = '$hr:$min';
    final repeatDays = _selectedDays.join(',');

    // 弹出等待音频合成的阻断性 Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.brandPink),
            SizedBox(width: 20),
            Expanded(child: Text('正在合成伴侣语音包，请稍候...')),
          ],
        ),
      ),
    );

    try {
      Reminder reminder;
      if (widget.reminder == null) {
        // 创建
        reminder = await apiService.createReminder(
          companionId: _selectedCompanionId!,
          reminderTime: reminderTime,
          textTemplate: _templateController.text.trim(),
          type: _selectedType,
          repeatDays: repeatDays,
          enabled: _enabled ? 1 : 0,
        );
      } else {
        // 更新
        final id = widget.reminder!.id;
        await apiService.updateReminder(
          id,
          companionId: _selectedCompanionId,
          reminderTime: reminderTime,
          textTemplate: _templateController.text.trim(),
          type: _selectedType,
          repeatDays: repeatDays,
          enabled: _enabled ? 1 : 0,
        );
        reminder = widget.reminder!.copyWith(
          companionId: _selectedCompanionId!,
          reminderTime: reminderTime,
          textTemplate: _templateController.text.trim(),
          type: _selectedType,
          repeatDays: repeatDays,
          enabled: _enabled ? 1 : 0,
        );
      }

      // 等待初次语音包合成下载完成
      if (_enabled) {
        await scheduler.downloadAndCacheAudio(reminder);
      }

      if (mounted) {
        // 关闭 Dialog
        Navigator.of(context).pop();
        // 返回成功
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        // 关闭 Dialog
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final hr = _selectedTime.hour.toString().padLeft(2, '0');
    final min = _selectedTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hr:$min';

    final weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF5F5F9),
      appBar: AppBar(
        title: Text(widget.reminder == null ? '新建定时提醒' : '编辑定时提醒'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading && _companions.isEmpty
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 2.5,
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 伴侣选择
                    _buildSectionTitle('选择呼叫伴侣', isDark),
                    const SizedBox(height: 10),
                    _companions.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('请先去伴侣管理中创建伴侣', style: TextStyle(color: Colors.red)),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedCompanionId,
                                items: _companions.map((companion) {
                                  return DropdownMenuItem<int>(
                                    value: companion.id,
                                    child: Row(
                                      children: [
                                        if (companion.avatarUrl != null)
                                          CircleAvatar(
                                            backgroundImage: NetworkImage(getFullUrl(ref, companion.avatarUrl!)),
                                            radius: 14,
                                          )
                                        else
                                          const CircleAvatar(
                                            child: Icon(Icons.person, size: 14),
                                          ),
                                        const SizedBox(width: 12),
                                        Text(companion.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCompanionId = val;
                                  });
                                },
                                hint: const Text('请选择伴侣'),
                                dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              ),
                            ),
                          ),
                    const SizedBox(height: 24),

                    // 提醒时间
                    _buildSectionTitle('选择时间', isDark),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.brandPink.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.access_time_filled_rounded, color: AppColors.brandPink, size: 24),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 重复星期
                    _buildSectionTitle('重复模式', isDark),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              final day = index + 1;
                              final isSelected = _selectedDays.contains(day);
                              return GestureDetector(
                                onTap: () => _toggleDay(day),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.brandPink
                                        : isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    weekLabels[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedDays.isEmpty
                                ? '仅响铃一次'
                                : '每周 ${_selectedDays.map((d) => weekLabels[d - 1]).join('、')} 响铃',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 提醒类型
                    _buildSectionTitle('提醒类型', isDark),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedType = 'WAKE_UP'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedType == 'WAKE_UP'
                                    ? AppColors.brandPink.withOpacity(0.12)
                                    : isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedType == 'WAKE_UP'
                                      ? AppColors.brandPink
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_in_talk_rounded,
                                      color: _selectedType == 'WAKE_UP' ? AppColors.brandPink : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    '来电叫醒',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedType == 'WAKE_UP'
                                          ? AppColors.brandPink
                                          : isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedType = 'NOTIFICATION'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedType == 'NOTIFICATION'
                                    ? AppColors.brandPink.withOpacity(0.12)
                                    : isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedType == 'NOTIFICATION'
                                      ? AppColors.brandPink
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_note_rounded,
                                      color: _selectedType == 'NOTIFICATION' ? AppColors.brandPink : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    '日程通知',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedType == 'NOTIFICATION'
                                          ? AppColors.brandPink
                                          : isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 朗读内容模板
                    _buildSectionTitle('伴侣朗读文本', isDark),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _templateController,
                            maxLines: 4,
                            maxLength: 200,
                            style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black),
                            decoration: const InputDecoration(
                              hintText: '请输入接通后伴侣会对你朗读的话...',
                              border: InputBorder.none,
                              counterStyle: TextStyle(fontSize: 10),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return '请输入朗读文本模板';
                              }
                              return null;
                            },
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text('快捷模板选择：',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickTemplates.map((template) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _templateController.text = template['text']!;
                                    _selectedType = template['type']!;
                                  });
                                },
                                child: Chip(
                                  label: Text(template['label']!, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 保存按钮
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.reminder == null ? '保存并同步语音' : '保存修改',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
      ),
    );
  }
}
