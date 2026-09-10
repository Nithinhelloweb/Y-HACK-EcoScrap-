import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecoscrap/main.dart';
import 'package:ecoscrap/services/offline_store.dart';
import 'package:ecoscrap/services/auth_service.dart';

void main() {
  testWidgets('EcoScrap App login screen renders by default', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final offlineStore = OfflineStore();
    await offlineStore.init();

    final authService = AuthService();
    await authService.init();

    await tester.pumpWidget(EcoScrapApp(
      offlineStore: offlineStore,
      authService: authService,
    ));
    await tester.pumpAndSettle();

    // Verify Unified Login Screen components
    expect(find.text('EcoScrap'), findsWidgets);
    expect(find.text('Sign In to EcoScrap'), findsOneWidget);
    expect(find.text('Sign In as COLLECTOR'), findsOneWidget);
    expect(find.text('Collector'), findsWidgets);
    expect(find.text('Recycler'), findsWidgets);
    expect(find.text('Admin'), findsWidgets);
  });
}
