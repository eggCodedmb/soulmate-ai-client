class SubscriptionStatus {
  final String planCode;
  final String planName;
  final int maxDailyMessages;
  final int todayUsedMessages;
  final int remainingMessages;
  final int maxCompanions;
  final int currentCompanions;
  final DateTime? expireTime;

  SubscriptionStatus({
    required this.planCode,
    required this.planName,
    required this.maxDailyMessages,
    required this.todayUsedMessages,
    required this.remainingMessages,
    required this.maxCompanions,
    required this.currentCompanions,
    this.expireTime,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      planCode: json['planCode'] as String? ?? 'FREE',
      planName: json['planName'] as String? ?? '免费版',
      maxDailyMessages: json['maxDailyMessages'] as int? ?? 50,
      todayUsedMessages: json['todayUsedMessages'] as int? ?? 0,
      remainingMessages: json['remainingMessages'] as int? ?? 50,
      maxCompanions: json['maxCompanions'] as int? ?? 1,
      currentCompanions: json['currentCompanions'] as int? ?? 0,
      expireTime: json['expireTime'] != null ? DateTime.parse(json['expireTime'] as String) : null,
    );
  }
}
