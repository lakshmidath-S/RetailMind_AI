import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/product_catalog.dart';
import 'models/product.dart';
import 'models/bill_item.dart';
import 'services/voice_bill_decoder.dart';
import 'services/audio_recording_service.dart';
import 'services/whisper_model_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/payment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  SyncService.instance.startListening();
  runApp(const RetailMindApp());
}

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
      home: const AuthGate(),
    );
  }
}

/// Routes to LoginScreen or HomeScreen based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (AuthService.isLoggedIn) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RetailMind AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Customers',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CustomersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => AuthService.signOut(),
          ),
        ],
      ),
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
  final AudioRecordingService _audioService = AudioRecordingService();

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final hasPermission = await _audioService.hasPermission();
      if (hasPermission) {
        await WhisperModelService.getModelPath(); // Warm up model
        await _audioService.startRecording();
        setState(() => _isListening = true);
      }
      return;
    }

    final path = await _audioService.stopRecording();
    setState(() => _isListening = false);
    
    if (path != null) {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingBillScreen(
            audioPath: path,
          ),
        ),
      );
    }
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
  const ProcessingBillScreen({required this.audioPath, super.key});

  final String audioPath;

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
    if (!mounted) return;
    try {
      final draft = await VoiceBillDecoder.decode(widget.audioPath, productCatalog);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => DraftBillScreen(draft: draft)),
      );
    } catch (e) {
      print('Error decoding bill: $e');
      if (!mounted) return;
      Navigator.of(context).pop();
    }
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
              const DecodedBill(
                transcript: VoiceBillDecoder.demoTranscript,
                items: [],
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
                onPressed: _items.isEmpty
                    ? null
                    : () {
                        final billItems = _items.map((line) => BillItem(
                          billId: 0, // Will be set by createCompleteBill
                          productId: line.product.id ?? 0,
                          quantity: line.quantity,
                          priceAtTime: line.product.price,
                        )).toList();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PaymentScreen(
                              totalAmount: _total,
                              billItems: billItems,
                            ),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: const Text('Proceed to Payment'),
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
