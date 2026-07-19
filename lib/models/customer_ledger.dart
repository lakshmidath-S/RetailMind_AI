class CustomerLedgerEntry {
  final int? id;
  final int customerId;
  final double amountPaid;
  final DateTime date;
  final String? note;

  CustomerLedgerEntry({
    this.id,
    required this.customerId,
    required this.amountPaid,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount_paid': amountPaid,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory CustomerLedgerEntry.fromMap(Map<String, dynamic> map) {
    return CustomerLedgerEntry(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      amountPaid: (map['amount_paid'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}
