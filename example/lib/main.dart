import 'package:flutter/material.dart';
import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Example app for `openpanel_dart`.
///
/// Runs on iOS, Android, Web, Windows, macOS and Linux.
///
/// paste the URL of your OpenPanel instance and a client id, then press *Initialize*.
/// A self-hosted instance can be reached through a custom [OpenpanelConfig.apiUrl]
/// and, when needed, extra headers such as `Origin`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional automatic tracking helpers:
  // - referrer reading on Android / iOS (no-op elsewhere)
  // - best-effort queue flush when the app is backgrounded or resumed.
  final analytics = OpenpanelAnalytics.instance;
  WidgetsBinding.instance
    ..addObserver(OpenpanelReferrerObserver(analytics: analytics))
    ..addObserver(OpenpanelLifecycleObserver(analytics: analytics));

  runApp(const OpenpanelExampleApp());
}

class OpenpanelExampleApp extends StatelessWidget {
  const OpenpanelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'openpanel_dart example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
      // Tracks every route change as a `screen_view` event automatically.
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
  static const _prefsUrl = 'example.api_url';
  static const _prefsClientId = 'example.client_id';
  static const _prefsSecret = 'example.client_secret';
  static const _prefsOrigin = 'example.origin';

  final _urlController = TextEditingController(text: kDefaultApiUrl);
  final _clientIdController = TextEditingController();
  final _secretController = TextEditingController();
  final _originController = TextEditingController(text: 'https://example.com');

  final List<String> _log = <String>[];
  int _pending = 0;
  bool _initializing = false;

  OpenpanelAnalytics get analytics => OpenpanelAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _clientIdController.dispose();
    _secretController.dispose();
    _originController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString(_prefsUrl) ?? kDefaultApiUrl;
      _clientIdController.text = prefs.getString(_prefsClientId) ?? '';
      _secretController.text = prefs.getString(_prefsSecret) ?? '';
      _originController.text =
          prefs.getString(_prefsOrigin) ?? 'https://example.com';
    });
  }

  Future<void> _refreshPending() async {
    final pending = await analytics.pendingEventCount();
    if (mounted) {
      setState(() => _pending = pending);
    }
  }

  void _logMessage(String message) {
    setState(() => _log.insert(0, message));
  }

  Future<void> _initialize() async {
    setState(() => _initializing = true);
    final prefs = await SharedPreferences.getInstance();
    final url = _urlController.text.trim();
    final clientId = _clientIdController.text.trim();
    final secret = _secretController.text.trim();
    final origin = _originController.text.trim();
    await prefs.setString(_prefsUrl, url);
    await prefs.setString(_prefsClientId, clientId);
    await prefs.setString(_prefsSecret, secret);
    await prefs.setString(_prefsOrigin, origin);

    if (clientId.isEmpty) {
      _logMessage(
        'Set a client id first (Settings -> API Clients in OpenPanel).',
      );
      setState(() => _initializing = false);
      return;
    }

    await analytics.init(
      config: OpenpanelConfig(
        apiUrl: url,
        clientId: clientId,
        clientSecret: secret.isEmpty ? null : secret,
        headers: origin.isEmpty ? const {} : {'Origin': origin},
        verbose: true,
        autoFlush: true,
        onError: (error) => _logMessage('Error: $error'),
      ),
    );
    _logMessage('Initialized against $url');
    await _refreshPending();
    setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('openpanel_dart example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'OpenPanel analytics for Flutter, iOS, Android, Web, Windows, macOS, Linux.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API URL',
              helperText:
                  'Cloud or self-hosted instance, e.g. '
                  'https://analytics.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientIdController,
            decoration: const InputDecoration(
              labelText: 'Client ID',
              helperText: 'Project dashboard -> Settings -> Clients',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _secretController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Client Secret (optional)',
              helperText: 'Only needed for server-side events.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _originController,
            decoration: const InputDecoration(
              labelText: 'Origin header (optional)',
              helperText: 'Sent with every request, useful behind a proxy!',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _initializing ? null : _initialize,
            icon: const Icon(Icons.play_arrow),
            label: Text(_initializing ? 'Initializing...' : 'Initialize'),
          ),

          const Divider(height: 32),

          Row(
            children: [
              Icon(
                analytics.isInitialized
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: analytics.isInitialized ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analytics.isInitialized
                      ? 'Initialized, profile: ${analytics.profileId ?? 'anonymous'} '
                            '· pending: $_pending'
                      : 'Not initialized yet',
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.bolt),
                label: const Text('track demo_event'),
                onPressed: () async {
                  await analytics.track(
                    'demo_event',
                    properties: {
                      'source': 'example app',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );
                  _logMessage('track(demo_event)');
                  await _refreshPending();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.person_add),
                label: const Text('identify user_123'),
                onPressed: () async {
                  await analytics.identify(
                    profileId: 'user_123',
                    firstName: 'Jane',
                    lastName: 'Doe',
                    email: 'jane@example.com',
                    properties: {'plan': 'free'},
                  );
                  _logMessage('identify(user_123)');
                  await _refreshPending();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.add),
                label: const Text('increment visits'),
                onPressed: () async {
                  await analytics.increment(property: 'visits', value: 1);
                  _logMessage('increment(visits)');
                  await _refreshPending();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.groups),
                label: const Text('set group org_acme'),
                onPressed: () async {
                  await analytics.upsertGroup(
                    id: 'org_acme',
                    type: 'company',
                    name: 'Acme Inc',
                    properties: {'industry': 'software'},
                  );
                  await analytics.assignGroups(<String>['org_acme']);
                  _logMessage('group(org_acme) + assign_group');
                  await _refreshPending();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh),
                label: const Text('flush queue'),
                onPressed: () async {
                  await analytics.flush();
                  _logMessage('flush()');
                  await _refreshPending();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_sweep),
                label: const Text('clear all'),
                onPressed: () async {
                  await analytics.clear();
                  _logMessage('clear()');
                  await _refreshPending();
                },
              ),
            ],
          ),

          const Divider(height: 32),
          Text('Activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_log.isEmpty)
            const Text('Nothing yet. Initialize, then press the chips.')
          else
            for (final entry in _log.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $entry',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
        ],
      ),
    );
  }
}
