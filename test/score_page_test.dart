import 'package:domiscore/src/app.dart';
import 'package:domiscore/src/core/persistence/shared_prefs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders both team views', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const DominoScoreApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Team A'), findsOneWidget);
    expect(find.text('Team B'), findsOneWidget);
    expect(find.byType(IconButton), findsWidgets);
  });
}
