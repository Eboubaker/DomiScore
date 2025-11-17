import 'package:domiscore/src/core/persistence/shared_prefs_provider.dart';
import 'package:domiscore/src/features/game/game_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  group('GameController - Initialization', () {
    test('initializes with default values when no stored data', () {
      final state = container.read(gameControllerProvider);

      expect(state.mode, GameMode.allFives);
      expect(state.teamOne.score, 0);
      expect(state.teamTwo.score, 0);
      expect(state.teamOne.label, 'Team A');
      expect(state.teamTwo.label, 'Team B');
      expect(state.canUndo, false);
      expect(state.canRedo, false);
    });

    test('loads stored scores from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'team_one_score': 25,
        'team_two_score': 35,
        'game_mode': GameMode.block.index,
      });
      final prefs = await SharedPreferences.getInstance();
      final testContainer = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
      );

      final state = testContainer.read(gameControllerProvider);

      expect(state.mode, GameMode.block);
      expect(state.teamOne.score, 25);
      expect(state.teamTwo.score, 35);
      testContainer.dispose();
    });
  });

  group('GameController - Score Operations', () {
    test('addPoints adds points to team score', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, 10);
      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 0);

      controller.addPoints(TeamId.teamTwo, 15);
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 10);
      expect(state.teamTwo.score, 15);
    });

    test('addPoints clamps score at 0 minimum', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, -50);
      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);
    });

    test('addPoints clamps score at 9999 maximum', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, 10000);
      final state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 9999);
    });

    test('addPoints does nothing when delta is 0', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      final stateBefore = container.read(gameControllerProvider);
      controller.addPoints(TeamId.teamOne, 0);
      final stateAfter = container.read(gameControllerProvider);

      expect(stateAfter.teamOne.score, stateBefore.teamOne.score);
      expect(stateAfter.canUndo, stateBefore.canUndo);
    });

    test('setScore sets absolute score value', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.setScore(TeamId.teamOne, 42);
      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 42);

      controller.setScore(TeamId.teamOne, 100);
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 100);
    });

    test('setScore clamps value between 0 and 9999', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.setScore(TeamId.teamOne, -50);
      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);

      controller.setScore(TeamId.teamTwo, 15000);
      state = container.read(gameControllerProvider);
      expect(state.teamTwo.score, 9999);
    });

    test('resetScores sets both teams to 0', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 50);
      controller.addPoints(TeamId.teamTwo, 30);

      controller.resetScores();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.score, 0);
      expect(state.teamTwo.score, 0);
    });
  });

  group('GameController - Undo/Redo', () {
    test('undo reverses last action', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      controller.undo();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.score, 0);
      expect(state.canUndo, false);
      expect(state.canRedo, true);
    });

    test('redo restores undone action', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);
      controller.undo();

      controller.redo();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.score, 10);
      expect(state.canUndo, true);
      expect(state.canRedo, false);
    });

    test('multiple undo/redo operations work correctly', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 5);
      controller.addPoints(TeamId.teamOne, 10);
      controller.addPoints(TeamId.teamOne, 15);

      // Undo twice
      controller.undo();
      controller.undo();
      var state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 5);

      // Redo once
      controller.redo();
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 15);

      // Undo all
      controller.undo();
      controller.undo();
      state = container.read(gameControllerProvider);
      expect(state.teamOne.score, 0);
    });

    test('canUndo is true after action', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, 10);
      final state = container.read(gameControllerProvider);

      expect(state.canUndo, true);
    });

    test('canRedo is true after undo', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      controller.undo();
      final state = container.read(gameControllerProvider);

      expect(state.canRedo, true);
    });

    test('new action clears redo stack', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);
      controller.undo();

      controller.addPoints(TeamId.teamTwo, 5);
      final state = container.read(gameControllerProvider);

      expect(state.canRedo, false);
    });

    test('undo with empty stack does nothing', () {
      final controller = container.read(gameControllerProvider.notifier);
      final stateBefore = container.read(gameControllerProvider);

      controller.undo();
      final stateAfter = container.read(gameControllerProvider);

      expect(stateAfter.teamOne.score, stateBefore.teamOne.score);
      expect(stateAfter.canUndo, false);
    });

    test('redo with empty stack does nothing', () {
      final controller = container.read(gameControllerProvider.notifier);
      final stateBefore = container.read(gameControllerProvider);

      controller.redo();
      final stateAfter = container.read(gameControllerProvider);

      expect(stateAfter.teamOne.score, stateBefore.teamOne.score);
      expect(stateAfter.canRedo, false);
    });

    test('history limit is enforced at 50 items', () {
      final controller = container.read(gameControllerProvider.notifier);

      // Add 52 actions (exceeds limit of 50)
      for (int i = 0; i < 52; i++) {
        controller.addPoints(TeamId.teamOne, 1);
      }

      // Undo 50 times (the limit)
      for (int i = 0; i < 50; i++) {
        controller.undo();
      }

      final state = container.read(gameControllerProvider);
      // After 50 undos, we should be at score 2 (52 - 50 = 2)
      expect(state.teamOne.score, 2);
      expect(state.canUndo, false);
    });
  });

  group('GameController - Reset Streak', () {
    test('4 consecutive resets clear history and logs', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      // Perform 4 consecutive resets
      for (int i = 0; i < 4; i++) {
        controller.resetScores();
      }

      final state = container.read(gameControllerProvider);
      expect(state.canUndo, false);
      expect(state.teamOne.log, isEmpty);
      expect(state.teamTwo.log, isEmpty);
    });

    test('reset streak is broken by non-reset action', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.resetScores();
      controller.resetScores();
      controller.addPoints(TeamId.teamOne, 5); // Breaks streak
      controller.resetScores();
      controller.resetScores();

      final state = container.read(gameControllerProvider);
      // History should not be cleared since streak was broken
      expect(state.canUndo, true);
    });

    test('less than 4 resets do not clear history', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      // Only 3 resets
      for (int i = 0; i < 3; i++) {
        controller.resetScores();
      }

      final state = container.read(gameControllerProvider);
      expect(state.canUndo, true);
    });
  });

  group('GameController - Mode Toggle', () {
    test('toggleMode switches between allFives and block', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.toggleMode();
      var state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.block);

      controller.toggleMode();
      state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.allFives);
    });

    test('toggleMode adds to undo history', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.toggleMode();
      var state = container.read(gameControllerProvider);
      expect(state.canUndo, true);

      controller.undo();
      state = container.read(gameControllerProvider);
      expect(state.mode, GameMode.allFives);
    });

    test('toggleMode persists to SharedPreferences', () async {
      final controller = container.read(gameControllerProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      controller.toggleMode();

      expect(prefs.getInt('game_mode'), GameMode.block.index);
    });

    test('toggleMode clears reset streak', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.resetScores();
      controller.resetScores();
      controller.toggleMode(); // Should clear streak
      controller.resetScores();
      controller.resetScores();

      final state = container.read(gameControllerProvider);
      // History should not be cleared since streak was broken by mode toggle
      expect(state.canUndo, true);
    });
  });

  group('GameController - Action Logging', () {
    test('addPoints logs action to correct team', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, 10);
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.log, contains('add 10'));
      expect(state.teamTwo.log, isEmpty);
    });

    test('setScore logs action to correct team', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.setScore(TeamId.teamTwo, 42);
      final state = container.read(gameControllerProvider);

      expect(state.teamTwo.log, contains('set 42'));
      expect(state.teamOne.log, isEmpty);
    });

    test('resetScores logs to both teams', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.resetScores();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.log, contains('reset'));
      expect(state.teamTwo.log, contains('reset'));
    });

    test('toggleMode logs to both teams', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.toggleMode();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.log, contains('mode block'));
      expect(state.teamTwo.log, contains('mode block'));
    });

    test('log limit is enforced at 3 items', () {
      final controller = container.read(gameControllerProvider.notifier);

      controller.addPoints(TeamId.teamOne, 5);
      controller.addPoints(TeamId.teamOne, 10);
      controller.addPoints(TeamId.teamOne, 15);
      controller.addPoints(TeamId.teamOne, 20);

      final state = container.read(gameControllerProvider);
      expect(state.teamOne.log.length, 3);
      expect(state.teamOne.log, ['add 20', 'add 15', 'add 10']);
    });

    test('undo logs include original action description', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);

      controller.undo();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.log.first, contains('undo'));
      expect(state.teamOne.log.first, contains('add 10'));
    });

    test('redo logs include original action description', () {
      final controller = container.read(gameControllerProvider.notifier);
      controller.addPoints(TeamId.teamOne, 10);
      controller.undo();

      controller.redo();
      final state = container.read(gameControllerProvider);

      expect(state.teamOne.log.first, contains('redo'));
      expect(state.teamOne.log.first, contains('add 10'));
    });
  });

  group('GameController - Persistence', () {
    test('scores persist to SharedPreferences', () async {
      final controller = container.read(gameControllerProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      controller.addPoints(TeamId.teamOne, 25);
      controller.addPoints(TeamId.teamTwo, 35);

      expect(prefs.getInt('team_one_score'), 25);
      expect(prefs.getInt('team_two_score'), 35);
    });

    test('setScore persists to SharedPreferences', () async {
      final controller = container.read(gameControllerProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      controller.setScore(TeamId.teamOne, 100);

      expect(prefs.getInt('team_one_score'), 100);
    });

    test('undo persists scores to SharedPreferences', () async {
      final controller = container.read(gameControllerProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      controller.addPoints(TeamId.teamOne, 50);
      controller.undo();

      expect(prefs.getInt('team_one_score'), 0);
    });

    test('redo persists scores to SharedPreferences', () async {
      final controller = container.read(gameControllerProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      controller.addPoints(TeamId.teamOne, 50);
      controller.undo();
      controller.redo();

      expect(prefs.getInt('team_one_score'), 50);
    });
  });

  group('GameState', () {
    test('scoreFor returns correct team', () {
      final teamOne = TeamScore(id: TeamId.teamOne, label: 'A', score: 10);
      final teamTwo = TeamScore(id: TeamId.teamTwo, label: 'B', score: 20);
      final state = GameState(
        mode: GameMode.allFives,
        teamOne: teamOne,
        teamTwo: teamTwo,
      );

      expect(state.scoreFor(TeamId.teamOne), teamOne);
      expect(state.scoreFor(TeamId.teamTwo), teamTwo);
    });

    test('copyWith creates new state with updated fields', () {
      final original = GameState(
        mode: GameMode.allFives,
        teamOne: TeamScore(id: TeamId.teamOne, label: 'A', score: 0),
        teamTwo: TeamScore(id: TeamId.teamTwo, label: 'B', score: 0),
        canUndo: false,
        canRedo: false,
      );

      final updated = original.copyWith(
        mode: GameMode.block,
        canUndo: true,
      );

      expect(updated.mode, GameMode.block);
      expect(updated.canUndo, true);
      expect(updated.canRedo, false);
      expect(original.mode, GameMode.allFives); // Original unchanged
    });
  });

  group('TeamScore', () {
    test('copyWith creates new team with updated score', () {
      final original = TeamScore(
        id: TeamId.teamOne,
        label: 'Team A',
        score: 10,
        log: ['action 1'],
      );

      final updated = original.copyWith(score: 20);

      expect(updated.score, 20);
      expect(updated.id, TeamId.teamOne);
      expect(updated.label, 'Team A');
      expect(original.score, 10); // Original unchanged
    });

    test('copyWith creates new team with updated log', () {
      final original = TeamScore(
        id: TeamId.teamOne,
        label: 'Team A',
        score: 10,
        log: ['action 1'],
      );

      final updated = original.copyWith(log: ['action 2', 'action 1']);

      expect(updated.log, ['action 2', 'action 1']);
      expect(original.log, ['action 1']); // Original unchanged
    });

    test('copyWith preserves log as new list', () {
      final original = TeamScore(
        id: TeamId.teamOne,
        label: 'Team A',
        score: 10,
        log: ['action 1'],
      );

      final updated = original.copyWith(score: 20);

      // Modifying updated.log should not affect original
      expect(updated.log, isNot(same(original.log)));
    });
  });
}
