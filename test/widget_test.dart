import 'package:flutter_test/flutter_test.dart';
import 'package:geo_messenger/main.dart';

void main() {
  testWidgets('App renders auth gate', (WidgetTester tester) async {
    await tester.pumpWidget(const GeoMessengerApp());
    expect(find.byType(GeoMessengerApp), findsOneWidget);
  });
}
