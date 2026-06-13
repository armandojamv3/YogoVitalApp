class Fruit {
  final int id;
  final String name;
  final double priceAdjustment;

  Fruit({
    required this.id,
    required this.name,
    required this.priceAdjustment,
  });

  factory Fruit.fromJson(Map<String, dynamic> json) {
    return Fruit(
      id: json["id"],
      name: json["name"],
      priceAdjustment: json["price_adjustment"].toDouble(),
    );
  }
}
