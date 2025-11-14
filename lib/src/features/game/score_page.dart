import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'game_controller.dart';

class ScorePage extends ConsumerStatefulWidget {
  const ScorePage({super.key});

  @override
  ConsumerState<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends ConsumerState<ScorePage> {
  late final AppLifecycleListener _lifecycleListener;
  final Set<TeamId> _focusedBlockInputs = {};

  @override
  void initState() {
    super.initState();
    _keepScreenAwake();
    _lifecycleListener = AppLifecycleListener(
      onResume: _keepScreenAwake,
      onInactive: _allowSleep,
      onPause: _allowSleep,
    );
  }

  Future<void> _keepScreenAwake() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Ignore platform errors; app can still function without wakelock.
    }
  }

  Future<void> _allowSleep() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  void _handleBlockInputFocusChange(TeamId teamId, bool isFocused) {
    final changed = isFocused
        ? _focusedBlockInputs.add(teamId)
        : _focusedBlockInputs.remove(teamId);
    if (changed) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _allowSleep();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                game.mode == GameMode.allFives
                    ? 'All-Fives Mode'
                    : 'Block Mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TeamPanel(
                      team: game.teamOne,
                      teamId: TeamId.teamOne,
                      mode: game.mode,
                      hideLogs: _focusedBlockInputs.isNotEmpty,
                      onBlockInputFocusChange: (focused) =>
                          _handleBlockInputFocusChange(TeamId.teamOne, focused),
                      background: colorScheme.primaryContainer,
                      foreground: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Container(
                    width: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: TeamPanel(
                      team: game.teamTwo,
                      teamId: TeamId.teamTwo,
                      mode: game.mode,
                      hideLogs: _focusedBlockInputs.isNotEmpty,
                      onBlockInputFocusChange: (focused) =>
                          _handleBlockInputFocusChange(TeamId.teamTwo, focused),
                      background: colorScheme.secondaryContainer,
                      foreground: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ScoreToolbar(game: game),
    );
  }
}

class ScoreToolbar extends ConsumerWidget {
  const ScoreToolbar({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameController = ref.read(gameControllerProvider.notifier);
    final isAllFives = game.mode == GameMode.allFives;

    return BottomAppBar(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Tooltip(
            message: isAllFives ? 'Switch to Block mode' : 'Switch to All-Fives mode',
            child: IconButton.filledTonal(
              icon: Icon(isAllFives ? Icons.calculate : Icons.grid_view),
              onPressed: gameController.toggleMode,
            ),
          ),
          Tooltip(
            message: 'Undo last score change',
            child: IconButton.filledTonal(
              icon: const Icon(Icons.undo),
              onPressed: game.canUndo ? gameController.undo : null,
            ),
          ),
          Tooltip(
            message: 'Redo previously undone change',
            child: IconButton.filledTonal(
              icon: const Icon(Icons.redo),
              onPressed: game.canRedo ? gameController.redo : null,
            ),
          ),
          Tooltip(
            message: 'Reset both team scores',
            child: IconButton.filledTonal(
              icon: const Icon(Icons.refresh),
              onPressed: gameController.resetScores,
            ),
          ),
        ],
      ),
    );
  }
}

class TeamPanel extends ConsumerStatefulWidget {
  const TeamPanel({
    super.key,
    required this.team,
    required this.teamId,
    required this.mode,
    required this.hideLogs,
    required this.onBlockInputFocusChange,
    required this.background,
    required this.foreground,
  });

  final TeamScore team;
  final TeamId teamId;
  final GameMode mode;
  final bool hideLogs;
  final ValueChanged<bool> onBlockInputFocusChange;
  final Color background;
  final Color foreground;

  @override
  ConsumerState<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends ConsumerState<TeamPanel> {
  final TextEditingController _blockInputController = TextEditingController();
  final FocusNode _blockInputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _blockInputFocusNode.addListener(_handleBlockInputFocusChange);
  }

  @override
  void dispose() {
    _blockInputFocusNode.removeListener(_handleBlockInputFocusChange);
    _blockInputFocusNode.dispose();
    _blockInputController.dispose();
    super.dispose();
  }

  void _handleBlockInputFocusChange() {
    widget.onBlockInputFocusChange(_blockInputFocusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final gameController = ref.read(gameControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: InkWell(
                onTap: () => _showScoreEditDialog(context, widget.team),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.background,
                        widget.background.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.team.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: widget.foreground.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                          child: child,
                        ),
                        child: Text(
                          '${widget.team.score}',
                          key: ValueKey('score-${widget.team.id}-${widget.team.score}'),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.foreground,
                                fontSize: 72,
                              ),
                        ),
                      ).animate(key: ValueKey(widget.team.score)).fadeIn().scale(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: widget.mode == GameMode.allFives
                          ? _QuickAddGrid(teamId: widget.teamId)
                          : _BlockEntry(
                              controller: _blockInputController,
                              focusNode: _blockInputFocusNode,
                              onSubmit: (value) {
                                gameController.addPoints(widget.teamId, value);
                                _blockInputController.clear();
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    if (!widget.hideLogs)
                      _ScoreLog(logs: widget.team.log),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScoreEditDialog(BuildContext context, TeamScore team) async {
    final notifier = ref.read(gameControllerProvider.notifier);
    final newValue = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _ScoreEditDialog(team: team),
    );

    if (!context.mounted) return;

    if (newValue != null) {
      final theme = Theme.of(context);
      notifier.setScore(team.id, newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${team.label} score updated'), backgroundColor: theme.colorScheme.primary),
      );
    }
  }
}

class _QuickAddGrid extends ConsumerWidget {
  const _QuickAddGrid({required this.teamId});

  final TeamId teamId;

  static const quickValues = [5, 10, 15, 20, 25, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 420 ? 3 : 2;

        final textStyle = Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
          ),
          itemCount: quickValues.length,
          itemBuilder: (context, index) {
            final value = quickValues[index];
            final label = '+$value';

            return FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: textStyle,
              ),
              onPressed: () => controller.addPoints(teamId, value),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                ),
              ),
            ).animate().slideY(begin: 0.12, duration: 220.ms).fadeIn(duration: 260.ms);
          },
        );
      },
    );
  }
}

class _BlockEntry extends StatelessWidget {
  const _BlockEntry({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(int value) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Add score',
            hintText: 'Enter points',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (value) => _trySubmit(value, context),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _trySubmit(controller.text, context),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }

  void _trySubmit(String rawValue, BuildContext context) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number to add score.')),
      );
      return;
    }
    onSubmit(parsed);
    FocusScope.of(context).unfocus();
  }
}

class _ScoreLog extends StatelessWidget {
  const _ScoreLog({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final entries = logs.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: entries
            .map(
              (entry) => Text(
                entry,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ScoreEditDialog extends StatefulWidget {
  const _ScoreEditDialog({required this.team});

  final TeamScore team;

  @override
  State<_ScoreEditDialog> createState() => _ScoreEditDialogState();
}

class _ScoreEditDialogState extends State<_ScoreEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? rawValue]) {
    final parsed = int.tryParse((rawValue ?? _controller.text).trim());
    if (parsed != null) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.team.label} score'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
        decoration: const InputDecoration(labelText: 'Set score'),
        autofocus: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set'),
        ),
      ],
    );
  }
}
