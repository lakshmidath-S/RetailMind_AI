import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/customer.dart';
import '../models/customer_ledger.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseHelper.instance;
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await _db.getAllCustomers();
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  Future<void> _addCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _db.insertCustomer(Customer(name: nameController.text.trim(), phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim()));
      _loadCustomers();
    }
    nameController.dispose();
    phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers (Khata)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('No customers yet'),
                      const SizedBox(height: 8),
                      const Text('Add a customer when using Pay Later'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: customer.pendingAmount > 0
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: TextStyle(
                            color: customer.pendingAmount > 0
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(customer.name),
                      subtitle: customer.phone != null ? Text(customer.phone!) : null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${customer.pendingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: customer.pendingAmount > 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            customer.pendingAmount > 0 ? 'Pending' : 'Clear',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(customer: customer),
                          ),
                        );
                        _loadCustomers();
                      },
                    );
                  },
                ),
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({required this.customer, super.key});
  final Customer customer;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _db = DatabaseHelper.instance;
  late Customer _customer;
  List<CustomerLedgerEntry> _ledgerEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final entries = await _db.getLedgerEntries(_customer.id!);
    final refreshed = await _db.getCustomerById(_customer.id!);
    setState(() {
      _ledgerEntries = entries;
      if (refreshed != null) _customer = refreshed;
      _isLoading = false;
    });
  }

  Future<void> _settleBalance() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pending: ₹${_customer.pendingAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record Payment')),
        ],
      ),
    );

    if (result == true && amountController.text.isNotEmpty) {
      final amount = double.tryParse(amountController.text);
      if (amount != null && amount > 0) {
        await _db.insertLedgerEntry(CustomerLedgerEntry(
          customerId: _customer.id!,
          amountPaid: amount,
          date: DateTime.now(),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        ));
        _loadData();
      }
    }
    amountController.dispose();
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_customer.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance card
                  Card(
                    color: _customer.pendingAmount > 0 ? colors.errorContainer : colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            '₹${_customer.pendingAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _customer.pendingAmount > 0
                                  ? colors.onErrorContainer
                                  : colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _customer.pendingAmount > 0 ? 'Pending Balance' : 'All Clear!',
                            style: TextStyle(
                              color: _customer.pendingAmount > 0
                                  ? colors.onErrorContainer
                                  : colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_customer.pendingAmount > 0)
                    FilledButton.icon(
                      onPressed: _settleBalance,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Settle Balance'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  const SizedBox(height: 20),
                  Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _ledgerEntries.isEmpty
                        ? const Center(child: Text('No payments recorded yet'))
                        : ListView.builder(
                            itemCount: _ledgerEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _ledgerEntries[index];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.check_circle_outline)),
                                title: Text('₹${entry.amountPaid.toStringAsFixed(2)}'),
                                subtitle: Text(
                                  '${entry.date.day}/${entry.date.month}/${entry.date.year}'
                                  '${entry.note != null ? ' · ${entry.note}' : ''}',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
