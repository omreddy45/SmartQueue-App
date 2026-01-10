class QueueStats {
  final int totalOrdersToday;
  final int averageWaitTime;
  final String peakHour;
  final int activeQueueLength;

  QueueStats({
    required this.totalOrdersToday,
    required this.averageWaitTime,
    required this.peakHour,
    required this.activeQueueLength,
  });
}
