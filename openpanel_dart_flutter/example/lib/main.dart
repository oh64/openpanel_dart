import 'package:flutter/material.dart';
import 'package:openpanel_dart_flutter/openpanel_dart_flutter.dart';

/// Example app for `openpanel_dart_flutter`.
///
/// It wires the Flutter helpers (screen tracking, referrer and lifecycle
/// observers, `shared_preferences` storage) through `initOpenpanelFlutter` and exposes a few manual calls.
///
/// Replace `YOUR_CLIENT_ID` below (and, for a self-hosted instance, `apiUrl`)  to actually deliver events.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final analytics = OpenpanelAnalytics.instance;
  WidgetsBinding.instance
    ..addObserver(OpenpanelReferrerObserver(analytics: analytics))
    ..addObserver(OpenpanelLifecycleObserver(analytics: analytics));

  await initOpenpanelFlutter(
    analytics,
    config: const OpenpanelConfig(
      clientId: 'YOUR_CLIENT_ID',
      // Self-hosted? Point apiUrl at your own domain:
      // apiUrl: 'https://analytics.example.com',
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'openpanel_dart_flutter example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      // Every named route change is tracked as a `screen_view` event.
      navigatorObservers: [OpenpanelRouteObserver()],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OpenpanelAnalytics _analytics = OpenpanelAnalytics.instance;
  int _pending = 0;

  Future<void> _refresh() async {
    final pending = await _analytics.pendingEventCount();
    if (mounted) {
      setState(() => _pending = pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('openpanel_dart_flutter example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('pending events: $_pending'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await _analytics.track(
                  'button_clicked',
                  properties: const {'label': 'demo'},
                );
                await _refresh();
              },
              child: const Text('track button_clicked'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await _analytics.identify(
                  profileId: 'user_123',
                  email: 'jane@example.com',
                );
                await _refresh();
              },
              child: const Text('identify user_123'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/details'),
                  builder: (_) => const DetailsScreen(),
                ),
              ),
              child: const Text('open /details (screen_view)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await _analytics.flush();
                await _refresh();
              },
              child: const Text('flush queue'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: const Center(
        child: Text('Pushed route: a screen_view event was tracked.'),
      ),
    );
  }
}
