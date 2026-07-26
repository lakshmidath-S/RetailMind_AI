import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'config/supabase_config.dart';
import 'data/database_helper.dart';
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
import 'screens/products_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  // Seed the database with the initial catalog on first launch
  await DatabaseHelper.instance.seedFromCatalog(productCatalog);
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  int _productCount = 0;
  int _lowStockCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final products = await _db.getAllProducts();
    final lowStock = products.where((p) => p.stockQuantity <= 5).length;
    if (mounted) {
      setState(() {
        _productCount = products.length;
        _lowStockCount = lowStock;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ─── Welcome ───
              Text(
                'Welcome back!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your shop, create bills with voice, and track inventory.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Quick Stats ───
              if (!_isLoading)
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Products',
                        value: '$_productCount',
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Low Stock',
                        value: '$_lowStockCount',
                        color: _lowStockCount > 0 ? colors.error : Colors.green,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              // ─── Quick Actions ───
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // New Bill (primary action)
              _ActionCard(
                key: const Key('newBillButton'),
                icon: Icons.mic_rounded,
                title: 'New Voice Bill',
                subtitle: 'Speak items and quantities to create a bill',
                color: colors.primary,
                isPrimary: true,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NewBillScreen()),
                  );
                  _loadStats(); // Refresh stats after billing
                },
              ),
              const SizedBox(height: 12),

              // Manage Products
              _ActionCard(
                key: const Key('manageProductsButton'),
                icon: Icons.inventory_2_outlined,
                title: 'Manage Products',
                subtitle: 'Add, edit, delete products and update prices',
                color: colors.tertiary,
                badge: _lowStockCount > 0 ? '$_lowStockCount low' : null,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ProductsScreen()),
                  );
                  _loadStats();
                },
              ),
              const SizedBox(height: 12),

              // Customers / Khata
              _ActionCard(
                icon: Icons.people_outline,
                title: 'Customers (Khata)',
                subtitle: 'Manage customers and pending balances',
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CustomersScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: isPrimary ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: color.withOpacity(0.2)),
      ),
      color: isPrimary ? color : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                radius: 24,
                child: Icon(icon, color: isPrimary ? Colors.white : color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPrimary ? Colors.white : null,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isPrimary ? Colors.white70 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isPrimary ? Colors.white70 : color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BILLING SCREENS — Now fully DB-driven
// ═══════════════════════════════════════════════════════════════

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  bool _isListening = false;
  VoiceLanguage _selectedLanguage = VoiceLanguage.english;
  final AudioRecordingService _audioService = AudioRecordingService();

  // ── Recording timer ──
  final Stopwatch _recordingStopwatch = Stopwatch();
  Timer? _timerTick;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _timerTick?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final hasPermission = await _audioService.hasPermission();
      if (hasPermission) {
        await WhisperModelService.getModelPath(_selectedLanguage); // Warm up model
        await _audioService.startRecording();
        _recordingStopwatch.reset();
        _recordingStopwatch.start();
        _timerTick = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (mounted) {
            setState(() => _recordingDuration = _recordingStopwatch.elapsed);
          }
        });
        setState(() {
          _isListening = true;
          _recordingDuration = Duration.zero;
        });
      }
      return;
    }

    // ─── Stop recording ───
    _recordingStopwatch.stop();
    _timerTick?.cancel();
    final duration = _recordingStopwatch.elapsed;
    final path = await _audioService.stopRecording();
    setState(() => _isListening = false);

    if (path != null) {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingBillScreen(
            audioPath: path,
            language: _selectedLanguage,
            recordingDuration: duration,
          ),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
              SegmentedButton<VoiceLanguage>(
                segments: const [
                  ButtonSegment(value: VoiceLanguage.english, label: Text('English')),
                  ButtonSegment(value: VoiceLanguage.malayalam, label: Text('മലയാളം')),
                ],
                selected: {_selectedLanguage},
                onSelectionChanged: _isListening
                    ? null
                    : (Set<VoiceLanguage> newSelection) {
                        setState(() {
                          _selectedLanguage = newSelection.first;
                        });
                      },
              ),
              const SizedBox(height: 24),
              Icon(
                _isListening ? Icons.graphic_eq : Icons.mic_none_rounded,
                size: 88,
                color: _isListening ? colors.error : colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_isListening) ...[
                const SizedBox(height: 16),
                Text(
                  _formatDuration(_recordingDuration),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.error,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
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
  const ProcessingBillScreen({
    required this.audioPath,
    required this.language,
    this.recordingDuration,
    super.key,
  });

  final String audioPath;
  final VoiceLanguage language;
  final Duration? recordingDuration;

  @override
  State<ProcessingBillScreen> createState() => _ProcessingBillScreenState();
}

class _ProcessingBillScreenState extends State<ProcessingBillScreen> {
  int _progressPercent = 0;
  String _stepLabel = 'Loading model...';
  DateTime? _inferenceStart;
  String _estimatedTimeLeft = '';

  // Rough model speed factors (seconds of processing per second of audio)
  // These are conservative estimates for mid-range Android devices.
  static const _speedFactors = <WhisperModel, double>{
    WhisperModel.base: 0.8,
    WhisperModel.small: 2.5,
    WhisperModel.medium: 4.0, // medium Q5 is ~4× slower
  };

  @override
  void initState() {
    super.initState();
    _openDraftBill();
  }

  void _onProgress(int percent) {
    if (!mounted) return;
    setState(() {
      _progressPercent = percent;
      if (percent < 10) {
        _stepLabel = 'Loading model...';
      } else if (percent < 90) {
        _stepLabel = 'Transcribing audio...';
      } else {
        _stepLabel = 'Matching products...';
      }

      // Estimate time remaining
      if (_inferenceStart != null && percent > 5 && percent < 100) {
        final elapsed = DateTime.now().difference(_inferenceStart!);
        final totalEstimate = elapsed * (100 / percent);
        final remaining = totalEstimate - elapsed;
        final secs = remaining.inSeconds.clamp(1, 999);
        _estimatedTimeLeft = '~${secs}s remaining';
      } else if (percent >= 100) {
        _estimatedTimeLeft = 'Almost done...';
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  Future<void> _openDraftBill() async {
    if (!mounted) return;

    // Show initial estimate based on recording duration and model
    // We use the medium model (Q5) for both languages now
    final model = WhisperModel.medium;
    if (widget.recordingDuration != null) {
      final factor = _speedFactors[model] ?? 1.5;
      final estimatedSeconds = (widget.recordingDuration!.inSeconds * factor).ceil();
      if (mounted) {
        setState(() {
          _estimatedTimeLeft = '~${estimatedSeconds}s estimated';
        });
      }
    }

    _inferenceStart = DateTime.now();

    try {
      final dbProducts = await DatabaseHelper.instance.getAllProducts();
      final draft = await VoiceBillDecoder.decode(
        widget.audioPath,
        dbProducts,
        language: widget.language,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => DraftBillScreen(draft: draft)),
      );
    } catch (e) {
      print('Error decoding bill: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process voice: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _progressPercent / 100.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // ── Progress ring ──
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progressPercent > 0 ? progress : null,
                      strokeWidth: 6,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: colors.primary,
                    ),
                    Text(
                      _progressPercent > 0 ? '$_progressPercent%' : '...',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Step label ──
              Text(
                _stepLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // ── ETA ──
              if (_estimatedTimeLeft.isNotEmpty)
                Text(
                  _estimatedTimeLeft,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

              const SizedBox(height: 24),

              // ── Recording info ──
              if (widget.recordingDuration != null)
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_rounded, size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Audio: ${_formatDuration(widget.recordingDuration!)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.language_rounded, size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          widget.language.displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),

              // ── Linear progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressPercent > 0 ? progress : null,
                  minHeight: 6,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class BillLine {
  BillLine({
    required this.product,
    required this.quantity,
    this.confidence = 1.0,
  });

  factory BillLine.fromDecoded(DecodedBillItem item) {
    return BillLine(
      product: item.product,
      quantity: item.quantity,
      confidence: item.confidence,
    );
  }

  final Product product;
  int quantity;
  final double confidence;

  double get subtotal => quantity * product.price;
  double get gstAmount => subtotal * (product.gstPercentage / 100);
  double get total => subtotal + gstAmount;
}

class DraftBillScreen extends StatefulWidget {
  DraftBillScreen({DecodedBill? draft, super.key})
    : draft =
          draft ??
              const DecodedBill(
                transcript: '',
                items: [],
              );

  final DecodedBill draft;

  @override
  State<DraftBillScreen> createState() => _DraftBillScreenState();
}

class _DraftBillScreenState extends State<DraftBillScreen> {
  late final List<BillLine> _items;
  bool _isEditing = false;
  List<Product> _allDbProducts = [];

  @override
  void initState() {
    super.initState();
    _items = widget.draft.items.map(BillLine.fromDecoded).toList();
    _loadDbProducts();
  }

  Future<void> _loadDbProducts() async {
    _allDbProducts = await DatabaseHelper.instance.getAllProducts();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _totalGst => _items.fold(0, (sum, item) => sum + item.gstAmount);
  double get _total => _subtotal + _totalGst;

  Future<void> _addMissedItem() async {
    // Wait for DB products to load if they haven't yet
    if (_allDbProducts.isEmpty) {
      _allDbProducts = await DatabaseHelper.instance.getAllProducts();
    }

    final existingIds = _items.map((item) => item.product.id).toSet();
    final availableProducts = _allDbProducts
        .where((product) => !existingIds.contains(product.id))
        .toList();
    if (availableProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All products are already in the bill')),
        );
      }
      return;
    }

    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            const ListTile(title: Text('Add missed item', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final item in availableProducts)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(item.name[0].toUpperCase()),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.malayalamName.isNotEmpty ? '${item.malayalamName} · ' : ''}₹${item.price}'
                  '${item.unit != null ? ' / ${item.unit}' : ''}',
                ),
                trailing: Text(
                  '₹${item.price.toStringAsFixed(item.price == item.price.roundToDouble() ? 0 : 2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
              if (widget.draft.transcript.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Heard: "${widget.draft.transcript}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                    if (widget.draft.inferenceTime != null)
                      Text('Time to transcribe: ${widget.draft.inferenceTime!.inMilliseconds / 1000}s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              if (widget.draft.unmatchedSegments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Could not match: ${widget.draft.unmatchedSegments.join(", ")}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              if (_items.isNotEmpty)
                const Text('Please check the items before you proceed.'),
              if (_items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64,
                          color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        const Text('No items matched from your voice input.'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addMissedItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add items manually'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 16),
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
                if (_totalGst > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text('₹${_subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GST'),
                      Text('₹${_totalGst.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('₹${_total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall),
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
                                totalGst: _totalGst,
                                billItems: billItems,
                              ),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: const Text('Proceed to Payment'),
                ),
              ],
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
    // Confidence indicator color
    final confColor = item.confidence >= 0.9
        ? Colors.green
        : item.confidence >= 0.7
            ? Colors.orange
            : Colors.red;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Tooltip(
        message: '${(item.confidence * 100).toStringAsFixed(0)}% confidence',
        child: Icon(Icons.circle, color: confColor, size: 12),
      ),
      title: Text(item.product.name),
      subtitle: Text(
        '₹${item.product.price} each${item.product.gstPercentage > 0 ? ' (+${item.product.gstPercentage.toStringAsFixed(0)}% GST)' : ''}',
      ),
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
          : Text('${item.quantity} × ₹${item.product.price} = ₹${item.subtotal.toStringAsFixed(2)}'),
    );
  }
}
