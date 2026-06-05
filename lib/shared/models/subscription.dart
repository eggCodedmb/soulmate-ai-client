/// 订阅套餐
class SubscriptionPlan {
  final int id;
  final String planCode;
  final String planName;
  final double priceMonthly;
  final int maxCompanions;
  final int maxDailyMessages;
  final int voiceMessage;
  final int voiceCall;
  final int advancedMemory;
  final int customVoice;
  final int priorityResponse;
  final int displayOrder;
  final int status;

  const SubscriptionPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.priceMonthly,
    required this.maxCompanions,
    required this.maxDailyMessages,
    this.voiceMessage = 0,
    this.voiceCall = 0,
    this.advancedMemory = 0,
    this.customVoice = 0,
    this.priorityResponse = 0,
    this.displayOrder = 0,
    this.status = 1,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: (json['id'] as num).toInt(),
      planCode: json['planCode'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0,
      maxCompanions: (json['maxCompanions'] as num?)?.toInt() ?? 0,
      maxDailyMessages: (json['maxDailyMessages'] as num?)?.toInt() ?? 0,
      voiceMessage: (json['voiceMessage'] as num?)?.toInt() ?? 0,
      voiceCall: (json['voiceCall'] as num?)?.toInt() ?? 0,
      advancedMemory: (json['advancedMemory'] as num?)?.toInt() ?? 0,
      customVoice: (json['customVoice'] as num?)?.toInt() ?? 0,
      priorityResponse: (json['priorityResponse'] as num?)?.toInt() ?? 0,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'planCode': planCode,
    'planName': planName,
    'priceMonthly': priceMonthly,
    'maxCompanions': maxCompanions,
    'maxDailyMessages': maxDailyMessages,
    'voiceMessage': voiceMessage,
    'voiceCall': voiceCall,
    'advancedMemory': advancedMemory,
    'customVoice': customVoice,
    'priorityResponse': priorityResponse,
    'displayOrder': displayOrder,
    'status': status,
  };
}

/// 用户订阅
class UserSubscription {
  final int id;
  final int userId;
  final int planId;
  final DateTime startTime;
  final DateTime endTime;
  final int autoRenew;
  final int status;
  final DateTime? createTime;
  final DateTime? updateTime;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.startTime,
    required this.endTime,
    this.autoRenew = 1,
    this.status = 1,
    this.createTime,
    this.updateTime,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      planId: (json['planId'] as num).toInt(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      autoRenew: (json['autoRenew'] as num?)?.toInt() ?? 1,
      status: (json['status'] as num?)?.toInt() ?? 1,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'planId': planId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'autoRenew': autoRenew,
    'status': status,
    'createTime': createTime?.toIso8601String(),
    'updateTime': updateTime?.toIso8601String(),
  };
}
