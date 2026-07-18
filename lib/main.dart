import 'package:flutter/material.dart';

import 'data/product_catalog.dart';
import 'models/product.dart';
import 'services/voice_bill_decoder.dart';

void main() => runApp(const RetailMindApp());

class RetailMindApp extends StatelessWidget {
  const RetailMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RetailMind AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B45),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RetailMind AI')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ready to make a bill?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Speak the items and quantities. RetailMind will prepare the bill for you.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('newBillButton'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NewBillScreen()),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('New Bill'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  bool _isListening = false;

  Future<void> _toggleListening() async {
    if (!_isListening) {
      setState(() => _isListening = true);
      return;
    }

    setState(() => _isListening = false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProcessingBillScreen(
          transcript: VoiceBillDecoder.demoTranscript,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = _isListening ? 'Listening...' : 'Create a bill by voice';
    final instruction = _isListening
        ? 'Say all items and quantities. Tap the microphone again when you finish.'
        : 'Tap the microphone, then speak the items and quantities.';

    return Scaffold(
      appBar: AppBar(title: const Text('New Bill')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                _isListening ? Icons.graphic_eq : Icons.mic_none_rounded,
                size: 88,
                color: _isListening ? colors.error : colors.primary,
              ),
              const SizedBox(height: 28),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                key: const Key('voiceToggleButton'),
                onPressed: _toggleListening,
                style: FilledButton.styleFrom(
                  backgroundColor: _isListening ? colors.error : colors.primary,
                  minimumSize: const Size.fromHeight(72),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
                    const SizedBox(width: 12),
                    Text(_isListening ? 'Stop recording' : 'Start recording'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You can review and correct the bill after recording.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProcessingBillScreen extends StatefulWidget {
  const ProcessingBillScreen({required this.transcript, super.key});

  final String transcript;

  @override
  State<ProcessingBillScreen> createState() => _ProcessingBillScreenState();
}

class _ProcessingBillScreenState extends State<ProcessingBillScreen> {
  @override
  void initState() {
    super.initState();
    _openDraftBill();
  }

  Future<void> _openDraftBill() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final draft = VoiceBillDecoder.decode(widget.transcript, productCatalog);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => DraftBillScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Generating your bill...'),
              SizedBox(height: 8),
              Text('Checking items, quantities, and prices.'),
            ],
          ),
        ),
      ),
    );
  }
}

class BillLine {
  BillLine({required this.product, required this.quantity});

  factory BillLine.fromDecoded(DecodedBillItem item) {
    return BillLine(product: item.product, quantity: item.quantity);
  }

  final Product product;
  int quantity;

  double get total => quantity * product.price;
}

class DraftBillScreen extends StatefulWidget {
  DraftBillScreen({DecodedBill? draft, super.key})
    : draft =
          draft ??
              VoiceBillDecoder.decode(
                VoiceBillDecoder.demoTranscript,
                productCatalog,
              );

  final DecodedBill draft;

  @override
  State<DraftBillScreen> createState() => _DraftBillScreenState();
}

class _DraftBillScreenState extends State<DraftBillScreen> {
  late final List<BillLine> _items;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _items = widget.draft.items.map(BillLine.fromDecoded).toList();
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _addMissedItem() async {
    final existingIds = _items.map((item) => item.product.id).toSet();
    final availableProducts = productCatalog
        .where((product) => !existingIds.contains(product.id))
        .toList();
    if (availableProducts.isEmpty) return;

    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add missed item')),
            for (final item in availableProducts)
              ListTile(
                title: Text(item.name),
                subtitle: Text('${item.malayalamName} · ₹${item.price}'),
                onTap: () => Navigator.of(context).pop(item),
              ),
          ],
        ),
      ),
    );
    if (product != null && mounted) {
      setState(() => _items.add(BillLine(product: product, quantity: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review bill')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your bill is ready', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Heard: "${widget.draft.transcript}"'),
              const SizedBox(height: 4),
              const Text('Please check the items before you proceed.'),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) => _BillLineTile(
                    item: _items[index],
                    isEditing: _isEditing,
                    onRemove: () => setState(() => _items.removeAt(index)),
                    onQuantityChanged: (change) => setState(() {
                      _items[index].quantity =
                          (_items[index].quantity + change).clamp(1, 99);
                    }),
                  ),
                ),
              ),
              if (_isEditing)
                OutlinedButton.icon(
                  key: const Key('addItemButton'),
                  onPressed: _addMissedItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add missed item'),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text('₹$_total', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                OutlinedButton(
                  key: const Key('editBillButton'),
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Correct bill'),
                )
              else
                OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Done correcting'),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('proceedButton'),
                onPressed: _items.isEmpty ? null : () {},
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: const Text('Proceed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillLineTile extends StatelessWidget {
  const _BillLineTile({
    required this.item,
    required this.isEditing,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final BillLine item;
  final bool isEditing;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.product.name),
      subtitle: Text('₹${item.product.price} each'),
      trailing: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: () => onQuantityChanged(-1), icon: const Icon(Icons.remove)),
                Text('${item.quantity}'),
                IconButton(onPressed: () => onQuantityChanged(1), icon: const Icon(Icons.add)),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            )
          : Text('${item.quantity} × ₹${item.product.price} = ₹${item.total}'),
    );
  }
}
