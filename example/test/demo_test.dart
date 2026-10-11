import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:openpanel_dart_example/demo.dart';
import 'package:test/test.dart';

class _RecordingTransport implements TrackTransport {
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

  @override
  Future<TransportResult> send(TrackRequest request) async {
    sent.add(request.toBody());
    return const TransportSuccess();
  }

  @override
  Future<DeviceIdentity?> fetchDeviceId() async => null;

  @override
  void close() {}
}

void main() {
  test('runDemo sends identify, track and increment', () async {
    final transport = _RecordingTransport();
    final analytics = OpenpanelAnalytics(
      transport: transport,
      keyValueStore: InMemoryKeyValueStore(),
    );
    await analytics.init(
      config: OpenpanelConfig(
        clientId: 'client-1',
        apiUrl: 'https://analytics.example.com',
        flushInterval: Duration.zero,
        autoFlush: false,
        collectDeviceInfo: false,
        resolveDeviceId: false,
      ),
    );

    await runDemo(analytics);

    expect(
      transport.sent.map((event) => event['type']),
      containsAll(<String>['identify', 'track', 'increment']),
    );
    expect(await analytics.pendingEventCount(), 0);

    analytics.dispose();
  });
}
