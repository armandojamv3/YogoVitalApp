class Order {
  final int id;
  final int userId;
  final DateTime orderDate;
  final String status;
  final double totalAmount;
  final DateTime lastUpdated;

  Order({
    required this.id,
    required this.userId,
    required this.orderDate,
    required this.status,
    required this.totalAmount,
    required this.lastUpdated,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json["id"],
      userId: json["user_id"],
      orderDate: DateTime.parse(json["order_date"]),
      status: json["status"],
      totalAmount: json["total_amount"].toDouble(),
      lastUpdated: DateTime.parse(json["last_updated"]),
    );
  }
}
