import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cardscan_ai/main.dart';
import 'package:cardscan_ai/services/auth_service.dart';

void main() {
  testWidgets('login screen loads when signed out', (WidgetTester tester) async {
    dotenv.testLoad(fileInput: 'BASE_URL=http://localhost:8000\nAPI_KEY=test-key');
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
    await tester.pumpWidget(const CardScanApp());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
