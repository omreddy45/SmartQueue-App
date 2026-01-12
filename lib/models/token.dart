enum OrderStatus {
  WAITING,
  READY,
  COMPLETED,
  CANCELLED
}

class Token {
  final String id;
  final String canteenId;
  final String userId; // Added for Notification targeting
  final String couponCode;
  final String tokenNumber;
  final String foodItem; // Summary (e.g. "2x Vada Pav, 1x Coke")
  final List<Map<String, dynamic>>? items; // {name: "Vada Pav", quantity: 2}
  final OrderStatus status;
  final int timestamp;
  final int estimatedWaitTimeMinutes;
  final String? aiReasoning;
  final int? completedAt;
  final bool isOffline;

  Token({
    required this.id,
    required this.canteenId,
    required this.userId,
    required this.couponCode,
    required this.tokenNumber,
    required this.foodItem,
    this.items,
    required this.status,
    required this.timestamp,
    required this.estimatedWaitTimeMinutes,
    this.aiReasoning,
    this.completedAt,
    this.isOffline = false,
  });

  factory Token.fromJson(Map<dynamic, dynamic> json) {
    return Token(
      id: json['id'] as String,
      canteenId: json['canteenId'] as String,
      userId: json['userId'] as String? ?? '', // Fallback for old tokens
      couponCode: json['couponCode'] as String? ?? '',
      tokenNumber: json['tokenNumber'] as String,
      foodItem: json['foodItem'] as String,
      items: json['items'] != null 
          ? (json['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() 
          : null,
      status: OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == json['status'],
          orElse: () => OrderStatus.WAITING),
      timestamp: json['timestamp'] as int,
      estimatedWaitTimeMinutes: json['estimatedWaitTimeMinutes'] as int,
      aiReasoning: json['aiReasoning'] as String?,
      completedAt: json['completedAt'] as int?,
      isOffline: json['isOffline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canteenId': canteenId,
      'userId': userId,
      'couponCode': couponCode,
      'tokenNumber': tokenNumber,
      'foodItem': foodItem,
      'items': items,
      'status': status.toString().split('.').last,
      'timestamp': timestamp,
      'estimatedWaitTimeMinutes': estimatedWaitTimeMinutes,
      'aiReasoning': aiReasoning,
      'completedAt': completedAt,
      'isOffline': isOffline,
    };
  }
}
