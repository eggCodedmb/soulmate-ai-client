import 'package:dio/dio.dart';
import '../../../shared/models/reminder.dart';

/// 定时提醒模块 API
mixin ReminderMixin {
  Dio get dio;
  dynamic unwrap(Response<dynamic> response);

  /// 获取定时提醒列表
  Future<List<Reminder>> getReminderList() async {
    final response = await dio.get<dynamic>('/api/reminders/list');
    final data = unwrap(response) as List<dynamic>;
    return data
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取定时提醒详情
  Future<Reminder> getReminderDetail(int id) async {
    final response = await dio.get<dynamic>('/api/reminders/$id');
    return Reminder.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 创建定时提醒
  Future<Reminder> createReminder({
    required int companionId,
    required String reminderTime,
    required String textTemplate,
    required String type,
    String repeatDays = '',
    int enabled = 1,
  }) async {
    final response = await dio.post<dynamic>(
      '/api/reminders',
      data: {
        'companionId': companionId,
        'reminderTime': reminderTime,
        'textTemplate': textTemplate,
        'type': type,
        'repeatDays': repeatDays,
        'enabled': enabled,
      },
    );
    return Reminder.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  /// 更新定时提醒
  Future<void> updateReminder(int id, {
    int? companionId,
    String? reminderTime,
    String? textTemplate,
    String? type,
    String? repeatDays,
    int? enabled,
  }) async {
    final response = await dio.put<dynamic>(
      '/api/reminders/$id',
      data: {
        if (companionId != null) 'companionId': companionId,
        if (reminderTime != null) 'reminderTime': reminderTime,
        if (textTemplate != null) 'textTemplate': textTemplate,
        if (type != null) 'type': type,
        if (repeatDays != null) 'repeatDays': repeatDays,
        if (enabled != null) 'enabled': enabled,
      },
    );
    unwrap(response);
  }

  /// 删除定时提醒
  Future<void> deleteReminder(int id) async {
    final response = await dio.delete<dynamic>('/api/reminders/$id');
    unwrap(response);
  }
}
