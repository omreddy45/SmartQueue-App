class Canteen {
  final String id;
  final String name;
  final String campus;
  final String themeColor;

  Canteen({
    required this.id,
    required this.name,
    required this.campus,
    required this.themeColor,
  });

  factory Canteen.fromJson(Map<dynamic, dynamic> json) {
    return Canteen(
      id: json['id'] as String,
      name: json['name'] as String,
      campus: json['campus'] as String,
      themeColor: json['themeColor'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'campus': campus,
      'themeColor': themeColor,
    };
  }
}
