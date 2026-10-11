import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart_example/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the demo home screen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const OpenpanelExampleApp());

    expect(find.text('openpanel_dart example'), findsWidgets);
    expect(find.text('Initialize'), findsOneWidget);
    expect(find.text('Client ID'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('track demo_event'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('track demo_event'), findsOneWidget);
  });
}
