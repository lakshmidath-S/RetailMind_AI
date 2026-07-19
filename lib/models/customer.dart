class Customer {
  final int? id;
  final String name;
  final String? phone;
  final double pendingAmount;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.pendingAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'pending_amount': pendingAmount,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    double? pendingAmount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      pendingAmount: pendingAmount ?? this.pendingAmount,
    );
  }
}
