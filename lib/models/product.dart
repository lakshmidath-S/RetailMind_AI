import 'dart:convert';
import 'dart:typed_data';

class Product {
  final int? id;
  final String name;
  final String malayalamName;
  final String? category;
  final String? brand;
  final double price;
  final double gstPercentage;
  final String? unit;
  final int stockQuantity;
  final String? barcode;
  final String? imagePath;
  final Uint8List? embeddingVector;
  final List<String> aliases;

  const Product({
    this.id,
    required this.name,
    required this.malayalamName,
    this.category,
    this.brand,
    required this.price,
    this.gstPercentage = 0.0,
    this.unit,
    this.stockQuantity = 0,
    this.barcode,
    this.imagePath,
    this.embeddingVector,
    required this.aliases,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'malayalamName': malayalamName,
      'category': category,
      'brand': brand,
      'price': price,
      'gst_percentage': gstPercentage,
      'unit': unit,
      'stock_quantity': stockQuantity,
      'barcode': barcode,
      'image_path': imagePath,
      'embedding_vector': embeddingVector,
      'aliases': jsonEncode(aliases),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      malayalamName: map['malayalamName'] as String? ?? '',
      category: map['category'] as String?,
      brand: map['brand'] as String?,
      price: (map['price'] as num).toDouble(),
      gstPercentage: (map['gst_percentage'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String?,
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      barcode: map['barcode'] as String?,
      imagePath: map['image_path'] as String?,
      embeddingVector: map['embedding_vector'] as Uint8List?,
      aliases: (jsonDecode(map['aliases'] as String) as List<dynamic>).cast<String>(),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? malayalamName,
    String? category,
    String? brand,
    double? price,
    double? gstPercentage,
    String? unit,
    int? stockQuantity,
    String? barcode,
    String? imagePath,
    Uint8List? embeddingVector,
    List<String>? aliases,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      malayalamName: malayalamName ?? this.malayalamName,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      unit: unit ?? this.unit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      embeddingVector: embeddingVector ?? this.embeddingVector,
      aliases: aliases ?? this.aliases,
    );
  }
}

