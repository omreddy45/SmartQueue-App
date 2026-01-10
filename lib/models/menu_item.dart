class MenuItem {
  final String id;
  final String name;
  final String icon; // Handling as string identifier for Lucide/Material icons
  final String color; // Storing Tailwind/CSS class string for reference or mapping
  final double price;
  final bool isAvailable;
  final String category;

  MenuItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.price = 0.0,
    this.isAvailable = true,
    this.category = 'General',
  });

  factory MenuItem.fromJson(Map<dynamic, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      category: json['category'] as String? ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'price': price,
      'isAvailable': isAvailable,
      'category': category,
    };
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    double? price,
    bool? isAvailable,
    String? category,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      category: category ?? this.category,
    );
  }
}
