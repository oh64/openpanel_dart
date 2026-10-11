import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart_flutter_example/main.dart';

void main() {
  testWidgets('renders the example screen', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('openpanel_dart_flutter example'), findsOneWidget);
    expect(find.text('track button_clicked'), findsOneWidget);
    expect(find.text('pending events: 0'), findsOneWidget);
  });
}
