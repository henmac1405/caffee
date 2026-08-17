class MenuItem {
  final int id;
  final String name;
  final double price;
  final int discountPercent;
  final int tax; // <-- TAMBAHKAN PROPERTI PAJAK
  final String category;
  final String imagePath;
  int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.discountPercent,
    required this.tax, // <-- WAJIB DIISI
    required this.category,
    required this.imagePath,
    this.quantity = 1,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      discountPercent: int.tryParse(json['diskon_persen'].toString()) ?? 0,
      tax: int.tryParse(json['tax'].toString()) ?? 0, // <-- PARSING FIELD TAX
      category: json['category_name'] ?? json['category'] ?? '',
      imagePath: json['imagePath'] ?? '☕',
    );
  }
}
