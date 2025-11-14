import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/persistence/shared_prefs_provider.dart';

enum GameMode { allFives, block }

enum TeamId { teamOne, teamTwo }

class TeamScore {
  const TeamScore({
    required this.id,
    required this.label,
    required this.score,
    this.log = const [],
  });

  final TeamId id;
  final String label;
  final int score;
  final List<String> log;

  TeamScore copyWith({
    int? score,
    List<String>? log,
  }) =>
      TeamScore(
        id: id,
        label: label,
        score: score ?? this.score,
        log: log ?? List<String>.from(this.log),
      );
}

class GameState {
  const GameState({
    required this.mode,
    required this.teamOne,
    required this.teamTwo,
    this.canUndo = false,
    this.canRedo = false,
  });

  final GameMode mode;
  final TeamScore teamOne;
  final TeamScore teamTwo;
  final bool canUndo;
  final bool canRedo;

  TeamScore scoreFor(TeamId id) => id == TeamId.teamOne ? teamOne : teamTwo;

  GameState copyWith({
    GameMode? mode,
    TeamScore? teamOne,
    TeamScore? teamTwo,
    bool? canUndo,
    bool? canRedo,
  }) =>
      GameState(
        mode: mode ?? this.mode,
        teamOne: teamOne ?? this.teamOne,
        teamTwo: teamTwo ?? this.teamTwo,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  static const _modeKey = 'game_mode';
  static const _teamOneKey = 'team_one_score';
  static const _teamTwoKey = 'team_two_score';
  static const _historyLimit = 50;
  static const _logLimit = 3;
  static const _resetThreshold = 4;

  late final SharedPreferences _prefs;
  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];
  int _consecutiveResets = 0;

  @override
  GameState build() {
    _prefs = ref.watch(sharedPrefsProvider);
    _undoStack.clear();
    _redoStack.clear();
    final storedModeIndex = _prefs.getInt(_modeKey) ?? GameMode.allFives.index;
    final teamOneScore = _prefs.getInt(_teamOneKey) ?? 0;
    final teamTwoScore = _prefs.getInt(_teamTwoKey) ?? 0;

    return GameState(
      mode: GameMode.values[storedModeIndex.clamp(0, GameMode.values.length - 1)],
      teamOne: TeamScore(id: TeamId.teamOne, label: 'Team A', score: teamOneScore),
      teamTwo: TeamScore(id: TeamId.teamTwo, label: 'Team B', score: teamTwoScore),
    );
  }

  void toggleMode() {
    _clearResetStreak();
    final nextMode = state.mode == GameMode.allFives ? GameMode.block : GameMode.allFives;
    final description = 'mode ${_modeLabel(nextMode)}';
    _recordHistory(description, affectsBoth: true);
    _setState(state.copyWith(mode: nextMode));
    _prefs.setInt(_modeKey, nextMode.index);
    _logEvent(description, affectsBoth: true);
  }

  void resetScores() {
    const description = 'reset';
    _recordHistory(description, affectsBoth: true);
    _setState(state.copyWith(
      teamOne: state.teamOne.copyWith(score: 0),
      teamTwo: state.teamTwo.copyWith(score: 0),
    ));
    _persistScores();
    _logEvent(description, affectsBoth: true);
    _handleResetStreak();
  }

  void addPoints(TeamId id, int delta) {
    if (delta == 0) return;
    _clearResetStreak();
    final target = state.scoreFor(id);
    final nextValue = (target.score + delta).clamp(0, 9999);
    final description = 'add $delta';
    _updateScore(id, nextValue, description);
  }

  void setScore(TeamId id, int value) {
    _clearResetStreak();
    final sanitized = value.clamp(0, 9999);
    final description = 'set $sanitized';
    _updateScore(id, sanitized, description);
  }

  void _updateScore(TeamId id, int newValue, String description) {
    _recordHistory(description, teamId: id);
    final updatedTeam = state.scoreFor(id).copyWith(score: newValue);
    _setState(_replaceTeam(state, id, updatedTeam));
    _prefs.setInt(id == TeamId.teamOne ? _teamOneKey : _teamTwoKey, newValue);
    _logEvent(description, teamId: id);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _clearResetStreak();
    final entry = _undoStack.removeLast();
    _redoStack.add(_HistoryEntry(
      state: _snapshot(state),
      description: entry.description,
      teamId: entry.teamId,
      affectsBoth: entry.affectsBoth,
    ));
    _setState(entry.state);
    _persistScores();
    _logEvent('undo ${entry.description}',
        teamId: entry.teamId, affectsBoth: entry.affectsBoth);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _clearResetStreak();
    final entry = _redoStack.removeLast();
    _undoStack.add(_HistoryEntry(
      state: _snapshot(state),
      description: entry.description,
      teamId: entry.teamId,
      affectsBoth: entry.affectsBoth,
    ));
    _setState(entry.state);
    _persistScores();
    _logEvent('redo ${entry.description}',
        teamId: entry.teamId, affectsBoth: entry.affectsBoth);
  }

  void _recordHistory(String description, {TeamId? teamId, bool affectsBoth = false}) {
    _undoStack.add(
      _HistoryEntry(
        state: _snapshot(state),
        description: description,
        teamId: teamId,
        affectsBoth: affectsBoth || teamId == null,
      ),
    );
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  GameState _snapshot(GameState source) => GameState(
        mode: source.mode,
        teamOne: _cloneTeam(source.teamOne),
        teamTwo: _cloneTeam(source.teamTwo),
        canUndo: source.canUndo,
        canRedo: source.canRedo,
      );

  void _setState(GameState newState) {
    state = newState.copyWith(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  GameState _replaceTeam(GameState base, TeamId id, TeamScore updated) =>
      id == TeamId.teamOne ? base.copyWith(teamOne: updated) : base.copyWith(teamTwo: updated);

  TeamScore _cloneTeam(TeamScore team) => TeamScore(
        id: team.id,
        label: team.label,
        score: team.score,
        log: List<String>.from(team.log),
      );

  void _logEvent(String description, {TeamId? teamId, bool affectsBoth = false}) {
    if (description.isEmpty) return;
    if (affectsBoth || teamId == null) {
      _applyLogToTeam(TeamId.teamOne, description);
      _applyLogToTeam(TeamId.teamTwo, description);
      return;
    }
    _applyLogToTeam(teamId, description);
  }

  void _applyLogToTeam(TeamId id, String entry) {
    final target = state.scoreFor(id);
    final updatedLog = <String>[entry, ...target.log];
    final limited = updatedLog.length > _logLimit
        ? updatedLog.sublist(0, _logLimit)
        : updatedLog;
    final updatedTeam = target.copyWith(log: List<String>.from(limited));
    _setState(_replaceTeam(state, id, updatedTeam));
  }

  void _handleResetStreak() {
    _consecutiveResets += 1;
    if (_consecutiveResets >= _resetThreshold) {
      _consecutiveResets = 0;
      _clearHistoryAndLogs();
    }
  }

  void _clearResetStreak() {
    if (_consecutiveResets == 0) return;
    _consecutiveResets = 0;
  }

  void _clearHistoryAndLogs() {
    _undoStack.clear();
    _redoStack.clear();
    final clearedState = state.copyWith(
      teamOne: state.teamOne.copyWith(log: const []),
      teamTwo: state.teamTwo.copyWith(log: const []),
    );
    _setState(clearedState);
  }

  String _modeLabel(GameMode mode) => mode == GameMode.block ? 'block' : 'all-fives';

  void _persistScores() {
    _prefs
      ..setInt(_teamOneKey, state.teamOne.score)
      ..setInt(_teamTwoKey, state.teamTwo.score);
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.state,
    required this.description,
    this.teamId,
    this.affectsBoth = false,
  });

  final GameState state;
  final String description;
  final TeamId? teamId;
  final bool affectsBoth;
}
