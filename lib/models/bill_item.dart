class BillItem {
  final int? id;
  final int billId;
  final int productId;
  final int quantity;
  final double priceAtTime;

  BillItem({
    this.id,
    required this.billId,
    required this.productId,
    required this.quantity,
    required this.priceAtTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_id': billId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_time': priceAtTime,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      priceAtTime: (map['price_at_time'] as num).toDouble(),
    );
  }
}
