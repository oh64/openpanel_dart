import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingTransport implements TrackTransport {
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

  TransportResult Function(TrackRequest request)? responder;

  DeviceIdentity? deviceIdentity;

  @override
  Future<TransportResult> send(TrackRequest request) async {
    sent.add(request.toBody());
    final respond = responder;
    return respond?.call(request) ?? const TransportSuccess();
  }

  @override
  Future<DeviceIdentity?> fetchDeviceId() async => deviceIdentity;

  @override
  void close() {}
}

Future<void> waitForSent(RecordingTransport transport, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (transport.sent.length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
          'Timed out waiting for $count requests, got ${transport.sent.length}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingTransport transport;
  late OpenpanelAnalytics analytics;
  late List<OpenpanelError> errors;

  OpenpanelConfig testConfig({int maxAttempts = 3}) => OpenpanelConfig(
        clientId: 'client-1',
        apiUrl: 'https://selfhosted.example',
        flushInterval: Duration.zero,
        autoFlush: false,
        collectDeviceInfo: false,
        resolveDeviceId: false,
        maxAttempts: maxAttempts,
        retryBaseDelay: const Duration(milliseconds: 1),
        onError: errors.add,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    transport = RecordingTransport();
    errors = <OpenpanelError>[];
    analytics = OpenpanelAnalytics(transport: transport);
  });

  tearDown(() {
    analytics.dispose();
  });

  group('payload contracts (OpenAPI /track)', () {
    test('track', () async {
      await analytics.init(config: testConfig());
      await analytics.setProfileId('profile-1');
      await analytics
          .track('app_open', properties: <String, dynamic>{'foo': 'bar'});
      await analytics.flush();
      expect(transport.sent.single, <String, dynamic>{
        'type': 'track',
        'payload': <String, dynamic>{
          'name': 'app_open',
          'properties': <String, dynamic>{'foo': 'bar'},
          'profileId': 'profile-1',
        },
      });
    });

    test('track without profileId omits it', () async {
      await analytics.init(config: testConfig());
      await analytics.track('anon');
      await analytics.flush();
      final payload = transport.sent.single['payload'] as Map<String, dynamic>;
      expect(payload.containsKey('profileId'), isFalse);
      expect(payload['name'], 'anon');
    });

    test('track merges global properties and custom timestamp', () async {
      await analytics.init(config: testConfig());
      analytics.setGlobalProperties(<String, dynamic>{'app_version': '1.0'});
      await analytics.track(
        'purchase',
        properties: <String, dynamic>{'price': 9.99},
        timestamp: DateTime.utc(2026, 1, 15, 10, 30),
      );
      await analytics.flush();
      final properties = (transport.sent.single['payload']
          as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
      expect(properties['app_version'], '1.0');
      expect(properties['price'], 9.99);
      expect(properties['__timestamp'], '2026-01-15T10:30:00.000Z');
    });

    test('identify', () async {
      await analytics.init(config: testConfig());
      await analytics.identify(
        profileId: 'profile-1',
        firstName: 'Jane',
        avatar: 'https://example/avatar.png',
        properties: <String, dynamic>{'instance_url': 'https://i.example'},
      );
      await analytics.flush();
      expect(transport.sent.single, <String, dynamic>{
        'type': 'identify',
        'payload': <String, dynamic>{
          'profileId': 'profile-1',
          'firstName': 'Jane',
          'avatar': 'https://example/avatar.png',
          'properties': <String, dynamic>{'instance_url': 'https://i.example'},
        },
      });
      expect(analytics.profileId, 'profile-1');
    });

    test('increment and decrement', () async {
      await analytics.init(config: testConfig());
      await analytics.setProfileId('profile-1');
      await analytics.increment(property: 'messages', value: 2);
      await analytics.decrement(property: 'credits');
      await analytics.flush();
      expect(transport.sent[0], <String, dynamic>{
        'type': 'increment',
        'payload': <String, dynamic>{
          'profileId': 'profile-1',
          'property': 'messages',
          'value': 2,
        },
      });
      expect(transport.sent[1], <String, dynamic>{
        'type': 'decrement',
        'payload': <String, dynamic>{
          'profileId': 'profile-1',
          'property': 'credits',
          'value': 1,
        },
      });
    });

    test('group, assign_group and alias', () async {
      await analytics.init(config: testConfig());
      await analytics.setProfileId('profile-1');
      await analytics.upsertGroup(
        id: 'org_acme',
        type: 'company',
        name: 'Acme Inc',
        properties: <String, dynamic>{'plan': 'enterprise'},
      );
      await analytics.assignGroups(<String>['org_acme', 'team_eng']);
      await analytics.alias(alias: 'legacy-id');
      await analytics.flush();
      expect(transport.sent[0], <String, dynamic>{
        'type': 'group',
        'payload': <String, dynamic>{
          'id': 'org_acme',
          'type': 'company',
          'name': 'Acme Inc',
          'properties': <String, dynamic>{'plan': 'enterprise'},
        },
      });
      expect(transport.sent[1], <String, dynamic>{
        'type': 'assign_group',
        'payload': <String, dynamic>{
          'groupIds': <String>['org_acme', 'team_eng'],
          'profileId': 'profile-1',
        },
      });
      expect(transport.sent[2]['type'], 'alias');
      expect(
        (transport.sent[2]['payload'] as Map<String, dynamic>)['alias'],
        'legacy-id',
      );
    });

    test('setGroups attaches groups to subsequent track calls', () async {
      await analytics.init(config: testConfig());
      analytics.setGroups(<String>['org_acme']);
      await analytics.track('billing_view');
      await analytics.flush();
      final payload = transport.sent.single['payload'] as Map<String, dynamic>;
      expect(payload['groups'], <String>['org_acme']);
    });
  });

  group('delivery semantics', () {
    test('transient failures are retried until success', () async {
      var calls = 0;
      transport.responder = (request) {
        calls++;
        return calls < 3
            ? const TransportRetryable(message: 'server busy')
            : const TransportSuccess();
      };
      await analytics.init(config: testConfig(maxAttempts: 5));
      await analytics.track('x');
      await analytics.flush();
      await waitForSent(transport, 3);
      expect(await analytics.pendingEventCount(), 0);
    });

    test('events are dropped after reaching maxAttempts', () async {
      transport.responder =
          (_) => const TransportRetryable(message: 'always failing');
      await analytics.init(config: testConfig(maxAttempts: 3));
      await analytics.track('x');
      await analytics.flush();
      await waitForSent(transport, 3);
      expect(await analytics.pendingEventCount(), 0);
      await waitFor(
          () => errors.any((e) => e.kind == OpenpanelErrorKind.transport));
    });

    test('permanently invalid events are dropped without blocking the queue',
        () async {
      transport.responder =
          (_) => const TransportInvalid(statusCode: 422, message: 'nope');
      await analytics.init(config: testConfig());
      await analytics.track('bad');
      await analytics.track('good');
      await analytics.flush();
      await waitForSent(transport, 2);
      expect(await analytics.pendingEventCount(), 0);
      await waitFor(
          () => errors.any((e) => e.kind == OpenpanelErrorKind.invalidEvent));
    });

    test('401 pauses the client and reports a configuration error', () async {
      transport.responder = (_) =>
          const TransportFatal(statusCode: 401, message: 'bad client id');
      await analytics.init(config: testConfig());
      await analytics.track('x');
      await analytics.flush();
      await waitFor(
          () => errors.any((e) => e.kind == OpenpanelErrorKind.configuration));
      await analytics.track('y');
      await analytics.flush();
      expect(transport.sent.length, 1);
      expect(await analytics.pendingEventCount(), 2);
      transport.responder = null;
      analytics.resume();
      await waitForSent(transport, 3);
      expect(await analytics.pendingEventCount(), 0);
    });
  });

  group('identity and lifecycle', () {
    test('resolves device identity on init when enabled', () async {
      transport.deviceIdentity =
          const DeviceIdentity(deviceId: 'device-1', sessionId: 'session-1');
      final client = OpenpanelAnalytics(transport: transport);
      await client.init(
        config: OpenpanelConfig(
          clientId: 'client-1',
          resolveDeviceId: true,
          collectDeviceInfo: false,
          flushInterval: Duration.zero,
        ),
      );
      await waitFor(() => client.deviceId == 'device-1');
      expect(client.sessionId, 'session-1');
      client.dispose();
    });

    test('clear() resets the queue, identity and global properties', () async {
      await analytics.init(config: testConfig());
      await analytics.setProfileId('p1');
      analytics.setGlobalProperties(<String, dynamic>{'user_tier': 'premium'});
      analytics.setGroups(<String>['g1']);
      await analytics.track('x');
      await analytics.flush();
      expect(transport.sent.length, 1);

      await analytics.track('y');
      await analytics.clear();
      expect(await analytics.pendingEventCount(), 0);
      expect(analytics.profileId, isNull);

      await analytics.track('fresh');
      await analytics.flush();
      expect(transport.sent.length, 2);
      final sent = transport.sent.last['payload'] as Map<String, dynamic>;
      expect(sent['name'], 'fresh');
      expect(sent['properties'], isEmpty);
    });

    test('collection can be toggled on and off', () async {
      await analytics.init(config: testConfig());
      await analytics.setCollectionEnabled(false);
      await analytics.track('while_disabled');
      expect(await analytics.pendingEventCount(), 0);
      await analytics.setCollectionEnabled(true);
      await analytics.track('enabled_again');
      await analytics.flush();
      expect(transport.sent.length, 1);
      expect(
        (transport.sent.single['payload'] as Map<String, dynamic>)['name'],
        'enabled_again',
      );
    });
  });
}
