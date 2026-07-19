class Bill {
  final int? id;
  final DateTime createdAt;
  final double totalAmount;
  final double totalGst;
  final double discount;
  final String status;
  final String paymentMode; // 'CASH', 'UPI', or 'PAY_LATER'
  final int? customerId;    // Required when paymentMode is PAY_LATER

  Bill({
    this.id,
    required this.createdAt,
    required this.totalAmount,
    this.totalGst = 0.0,
    this.discount = 0.0,
    this.status = 'draft',
    this.paymentMode = 'CASH',
    this.customerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'total_gst': totalGst,
      'discount': discount,
      'status': status,
      'payment_mode': paymentMode,
      'customer_id': customerId,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalGst: (map['total_gst'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'draft',
      paymentMode: map['payment_mode'] as String? ?? 'CASH',
      customerId: map['customer_id'] as int?,
    );
  }
}
