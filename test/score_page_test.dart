import 'package:domiscore/src/app.dart';
import 'package:domiscore/src/core/persistence/shared_prefs_provider.dart';
import 'package:domiscore/src/features/game/game_controller.dart';
import 'package:domiscore/src/features/game/score_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ScorePage - Basic Rendering', () {
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

    testWidgets('displays initial score of 0 for both teams', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('displays All-Fives Mode label initially', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All-Fives Mode'), findsOneWidget);
    });
  });

  group('ScorePage - All-Fives Mode', () {
    testWidgets('displays all 6 quick-add buttons', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('+5'), findsNWidgets(2)); // One for each team
      expect(find.text('+10'), findsNWidgets(2));
      expect(find.text('+15'), findsNWidgets(2));
      expect(find.text('+20'), findsNWidgets(2));
      expect(find.text('+25'), findsNWidgets(2));
      expect(find.text('+30'), findsNWidgets(2));
    });

    testWidgets('quick-add button adds points to correct team', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Find Team A's +10 button (first one)
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );

      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      // Check that Team A score updated
      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 0);
    });

    testWidgets('multiple quick-add taps accumulate points', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+5'),
      );

      // Tap +5 three times
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 15);
    });
  });

  group('ScorePage - Block Mode', () {
    testWidgets('displays input field in Block mode', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle to Block mode
      final toggleButton = find.byIcon(Icons.calculate);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('Block Mode'), findsOneWidget);
      expect(find.text('Add score'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Add'), findsNWidgets(2));
    });

    testWidgets('numeric input accepts only digits', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      // Find first input field (Team A)
      final inputFields = find.byType(TextField);
      await tester.enterText(inputFields.first, '123abc');
      await tester.pumpAndSettle();

      // Should only have the digits
      final textField = tester.widget<TextField>(inputFields.first);
      expect(textField.controller?.text, '123');
    });

    testWidgets('submitting valid input adds points', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      // Find Team A's input field
      final inputFields = find.byType(TextField);
      await tester.enterText(inputFields.first, '42');
      await tester.pumpAndSettle();

      // Tap Add button
      final addButtons = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 42);
    });

    testWidgets('empty input shows error snackbar', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      // Tap Add without entering value
      final addButtons = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number to add score.'), findsOneWidget);
    });

    testWidgets('input clears after successful submit', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      final inputFields = find.byType(TextField);
      await tester.enterText(inputFields.first, '25');
      await tester.pumpAndSettle();

      final addButtons = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Input should be cleared
      final textField = tester.widget<TextField>(inputFields.first);
      expect(textField.controller?.text, isEmpty);
    });
  });

  group('ScorePage - Toolbar', () {
    testWidgets('mode toggle switches from All-Fives to Block', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All-Fives Mode'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      expect(find.text('Block Mode'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
    });

    testWidgets('undo button is disabled initially', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      final undoButton = find.byIcon(Icons.undo);
      final button = tester.widget<IconButton>(undoButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('undo button is enabled after action', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add points
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      final undoButton = find.byIcon(Icons.undo);
      final button = tester.widget<IconButton>(undoButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('redo button is disabled initially', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      final redoButton = find.byIcon(Icons.redo);
      final button = tester.widget<IconButton>(redoButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('redo button is enabled after undo', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add points then undo
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      final redoButton = find.byIcon(Icons.redo);
      final button = tester.widget<IconButton>(redoButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('reset button resets both scores', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add points to both teams
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      final teamBButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team B'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+15'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(teamBButtons.first);
      await tester.pumpAndSettle();

      // Reset
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);
      expect(state.teamTwo.score, 0);
    });
  });

  group('ScorePage - Score Display and Edit', () {
    testWidgets('tapping score opens edit dialog', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Team A score
      await tester.tap(find.text('0').first);
      await tester.pumpAndSettle();

      expect(find.text('Team A score'), findsOneWidget);
      expect(find.text('Set score'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);
    });

    testWidgets('score edit dialog can set new score', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('0').first);
      await tester.pumpAndSettle();

      // Enter new score
      await tester.enterText(find.byType(TextField).last, '99');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 99);
      expect(find.text('Team A score updated'), findsOneWidget);
    });

    testWidgets('score edit dialog cancel does not change score', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('0').first);
      await tester.pumpAndSettle();

      // Enter new score
      await tester.enterText(find.byType(TextField).last, '99');
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);
    });
  });

  group('ScorePage - Action Logs', () {
    testWidgets('action logs display after adding points', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add points
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('add 10'), findsAtLeastNWidgets(1));
    });

    testWidgets('reset action appears in both team logs', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Reset
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('reset'), findsNWidgets(2));
    });

    testWidgets('mode toggle action appears in both team logs', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      expect(find.text('mode block'), findsNWidgets(2));
    });
  });
}
