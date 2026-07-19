import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/customer.dart';

/// Shows the 3 payment options: Cash, UPI, Pay Later.
/// Returns the selected payment mode string, or null if cancelled.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    required this.totalAmount,
    required this.billItems,
    super.key,
  });

  final double totalAmount;
  final List<BillItem> billItems;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _db = DatabaseHelper.instance;

  Future<void> _completeBill(String paymentMode, {int? customerId}) async {
    final bill = Bill(
      createdAt: DateTime.now(),
      totalAmount: widget.totalAmount,
      status: 'completed',
      paymentMode: paymentMode,
      customerId: customerId,
    );

    await _db.createCompleteBill(bill: bill, items: widget.billItems);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bill saved! Payment: $paymentMode'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // Pop all the way back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handlePayLater() async {
    // Show customer selection or creation
    final customers = await _db.getAllCustomers();

    if (!mounted) return;
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => _CustomerPicker(
          customers: customers,
          scrollController: scrollController,
        ),
      ),
    );

    if (customer != null) {
      await _completeBill('PAY_LATER', customerId: customer.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total display
              Card(
                color: colors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Total Amount'),
                      const SizedBox(height: 8),
                      Text(
                        '₹${widget.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Choose payment method',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Cash
              _PaymentOptionCard(
                icon: Icons.payments_outlined,
                label: 'Cash',
                subtitle: 'Customer pays in cash',
                color: colors.primary,
                onTap: () => _completeBill('CASH'),
              ),
              const SizedBox(height: 12),

              // UPI
              _PaymentOptionCard(
                icon: Icons.qr_code_2,
                label: 'UPI',
                subtitle: 'Google Pay, PhonePe, etc.',
                color: colors.tertiary,
                onTap: () => _completeBill('UPI'),
              ),
              const SizedBox(height: 12),

              // Pay Later
              _PaymentOptionCard(
                icon: Icons.schedule,
                label: 'Pay Later',
                subtitle: 'Add to customer\'s pending balance',
                color: colors.error,
                onTap: _handlePayLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                radius: 24,
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker({
    required this.customers,
    required this.scrollController,
  });

  final List<Customer> customers;
  final ScrollController scrollController;

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _db = DatabaseHelper.instance;
  late List<Customer> _customers;

  @override
  void initState() {
    super.initState();
    _customers = widget.customers;
  }

  Future<void> _createNewCustomer() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Customer'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Customer Name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final id = await _db.insertCustomer(Customer(name: nameController.text.trim()));
      final customer = await _db.getCustomerById(id);
      if (customer != null && mounted) {
        Navigator.pop(context, customer);
      }
    }
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      children: [
        const ListTile(
          title: Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add)),
          title: const Text('Create New Customer'),
          onTap: _createNewCustomer,
        ),
        const Divider(),
        if (_customers.isEmpty)
          const ListTile(title: Text('No customers yet. Create one above.')),
        for (final customer in _customers)
          ListTile(
            leading: CircleAvatar(child: Text(customer.name[0].toUpperCase())),
            title: Text(customer.name),
            subtitle: customer.pendingAmount > 0
                ? Text('Pending: ₹${customer.pendingAmount.toStringAsFixed(2)}')
                : null,
            onTap: () => Navigator.pop(context, customer),
          ),
      ],
    );
  }
}
