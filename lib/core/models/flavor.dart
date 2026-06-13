class Flavor {
  final int id;
  final String name;
  final String description;
  final String? nutritionalInfo;

  Flavor({
    required this.id,
    required this.name,
    required this.description,
    this.nutritionalInfo,
  });

  factory Flavor.fromJson(Map<String, dynamic> json) {
    return Flavor(
      id: json["id"],
      name: json["name"],
      description: json["description"],
      nutritionalInfo: json["nutritional_info"],
    );
  }
}
