# DomiScore

Two-pane Flutter scorekeeper for domino matches. Track either All-Fives quick scoring or traditional Block rounds, keep undoable history, persist totals via SharedPreferences, and share a branded launcher icon/bundle (`io.github.eboubaker.domiscore`).

## DISCLAIMER
The app was completely "vibe-coded" with AI, The app is provided as-is without warranty. While functional, it may contain bugs or incomplete features. Use at your own risk.

## Highlights
- ⚖️ **Dual scoring modes** – quick-add chips for All-Fives (+5 … +30) and numeric entry for Block mode.
- 💾 **Persistent river of state** – Riverpod Notifier + SharedPreferences keep scores/mode alive between sessions.
- 🔁 **Undo & redo stack** – 50-step bounded history with redo, plus 4 rapid resets clear both history and per-team logs.
- 📝 **Per-team logs** – each side shows the last three actions (add/set/reset/undo); logs hide automatically when any score input is focused to maximize keyboard space.
- ✍️ **Editable totals** – tap a hero score to open a blank dialog, type a new total, and press enter/Set.
- 🌙 **Wakelock support** – `wakelock_plus` keeps the display awake during sessions (still allows dimming when backgrounded).
- 🎨 **Modern polish** – FlexColorScheme theming, Google Fonts text, Flutter Animate micro transitions, custom icon derived from `icon.jpg` via `flutter_launcher_icons`.

## Architecture
- `lib/src/features/game/game_controller.dart` holds the `GameController` Notifier with undo/redo stacks, per-team log slices (3 entries), and SharedPreferences persistence.
- `score_page.dart` renders two `TeamPanel`s, toggles wakelock in `ScorePage`, and hides both logs whenever any Block-mode text field is focused.
- Conveyor belt of widgets (Riverpod ProviderScope in `main.dart`, `DominoScoreApp` Material app wrapper, toolbar, quick-add grid).

## Getting Started
Prerequisites: Flutter SDK 3.10+, Android Studio or VS Code, and at least one connected device/emulator.

Install dependencies and run the static checks:

```bash
flutter pub get
flutter analyze
flutter test
```

Run the interactive debugger on a device (Impeller renderer is supported):

```bash
flutter run
```

Generate launcher icons again after tweaking `icon.jpg`:

```bash
flutter pub run flutter_launcher_icons:main
```

Produce a sideloadable APK (release variant outputs to `build/app/outputs/flutter-apk/app-release.apk`):

```bash
flutter build apk --release
```

## Usage Notes
- Tap a score to quickly edit the total; the dialog starts empty for faster overtyping.
- In Block mode the numeric field enforces digits only; submit with the Add button or the keyboard enter key.
- The log area hides while any Block entry field has focus, keeping the keyboard and form visible without overflow.
- Performing four resets in a row clears undo/redo stacks and trims both team logs to keep history meaningful.
- Undo/redo buttons in the bottom toolbar let you revisit past adjustments without losing current mode or wakelock state.
