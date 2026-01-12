class QueueStats {
  final int totalOrdersToday;
  final int averageWaitTime;
  final String peakHour;
  final int activeQueueLength;
  final Map<String, int> topItems; // Item Name -> Quantity

  QueueStats({
    required this.totalOrdersToday,
    required this.averageWaitTime,
    required this.peakHour,
    required this.activeQueueLength,
    required this.topItems,
  });
}
