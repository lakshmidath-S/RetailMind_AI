import 'package:flutter/material.dart';

void main() {
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
          brightness: Brightness.light,
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
      appBar: AppBar(
        title: const Text('RetailMind AI'),
        centerTitle: false,
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
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NewBillScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('New Bill'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: Theme.of(context).textTheme.titleMedium,
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

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String heading = _isListening ? 'Listening…' : 'Create a bill by voice';
    final String instruction = _isListening
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
