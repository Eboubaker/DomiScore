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

  group('Integration Tests - Complete Game Workflows', () {
    testWidgets('complete game scenario with multiple actions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Start in All-Fives mode
      expect(find.text('All-Fives Mode'), findsOneWidget);

      // Team A scores 10
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 0);

      // Team B scores 15
      final teamBButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team B'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+15'),
      );
      await tester.tap(teamBButtons.first);
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 15);

      // Team A scores 20 more
      final teamA20Buttons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+20'),
      );
      await tester.tap(teamA20Buttons.first);
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 30);

      // Undo last action
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.canRedo, true);

      // Redo action
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 30);

      // Switch to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      expect(find.text('Block Mode'), findsOneWidget);

      // Add 50 points to Team B using block mode
      final inputFields = find.byType(TextField);
      await tester.enterText(inputFields.last, '50');
      await tester.pumpAndSettle();

      final addButtons = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButtons.last);
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamTwo.score, 65);

      // Reset scores
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);
      expect(state.teamTwo.score, 0);

      container.dispose();
    });

    testWidgets('score persistence across app lifecycle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      var container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      // First app session
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add some scores
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+25'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      final teamBButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team B'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+30'),
      );
      await tester.tap(teamBButtons.first);
      await tester.pumpAndSettle();

      // Switch to Block mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 25);
      expect(state.teamTwo.score, 30);
      expect(state.mode, GameMode.block);

      // Verify persistence
      expect(prefs.getInt('team_one_score'), 25);
      expect(prefs.getInt('team_two_score'), 30);
      expect(prefs.getInt('game_mode'), GameMode.block.index);

      container.dispose();

      // Simulate app restart
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Scores should be restored
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 25);
      expect(state.teamTwo.score, 30);
      expect(state.mode, GameMode.block);
      expect(find.text('Block Mode'), findsOneWidget);

      container.dispose();
    });

    testWidgets('reset streak clears history after 4 consecutive resets', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add some points to create history
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.canUndo, true);
      expect(state.teamOne.log.isNotEmpty, true);

      // Perform 4 consecutive resets
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
      }

      // History and logs should be cleared
      state = container.read(gameControllerProvider);
      expect(state.canUndo, false);
      expect(state.teamOne.log, isEmpty);
      expect(state.teamTwo.log, isEmpty);

      container.dispose();
    });

    testWidgets('undo/redo workflow with mode changes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add points in All-Fives mode
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+5'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      // Toggle mode
      await tester.tap(find.byIcon(Icons.calculate));
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.block);
      expect(state.teamOne.score, 5);

      // Add more points in Block mode
      final inputFields = find.byType(TextField);
      await tester.enterText(inputFields.first, '10');
      await tester.pumpAndSettle();

      final addButtons = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 15);

      // Undo last action (should go back to 5 points)
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 5);

      // Undo again (should switch back to All-Fives mode)
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.allFives);

      // Undo again (should go back to 0 points)
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);

      // Redo all actions
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 5);

      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();
      state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.block);

      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 15);

      container.dispose();
    });

    testWidgets('score edit dialog workflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Add some points first
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);

      // Open edit dialog
      await tester.tap(find.text('10').first);
      await tester.pumpAndSettle();

      // Set to 150
      await tester.enterText(find.byType(TextField).last, '150');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 150);
      expect(find.text('Team A score updated'), findsOneWidget);

      // Verify undo works with setScore
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);

      container.dispose();
    });

    testWidgets('action logs track last 3 actions per team', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Perform 5 actions on Team A
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 5);
      await tester.pumpAndSettle();
      controller.addPoints(TeamId.teamOne, 10);
      await tester.pumpAndSettle();
      controller.addPoints(TeamId.teamOne, 15);
      await tester.pumpAndSettle();
      controller.addPoints(TeamId.teamOne, 20);
      await tester.pumpAndSettle();
      controller.addPoints(TeamId.teamOne, 25);
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider);
      // Should only have last 3 actions
      expect(state.teamOne.log.length, 3);
      expect(state.teamOne.log, ['add 25', 'add 20', 'add 15']);

      container.dispose();
    });

    testWidgets('mixed team actions with undo/redo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DominoScoreApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Team A scores
      final teamAButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team A'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+10'),
      );
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      // Team B scores
      final teamBButtons = find.descendant(
        of: find.ancestor(
          of: find.text('Team B'),
          matching: find.byType(TeamPanel),
        ),
        matching: find.text('+15'),
      );
      await tester.tap(teamBButtons.first);
      await tester.pumpAndSettle();

      // Team A scores again
      await tester.tap(teamAButtons.first);
      await tester.pumpAndSettle();

      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 20);
      expect(state.teamTwo.score, 15);

      // Undo Team A's second score
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 15);

      // Undo Team B's score
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 0);

      // Redo Team B's score
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();

      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 15);

      container.dispose();
    });
  });
}
