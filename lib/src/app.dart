import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/game/score_page.dart';

class DominoScoreApp extends StatelessWidget {
  const DominoScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.montserratTextTheme();
    return MaterialApp(
      title: 'DomiScore',
      debugShowCheckedModeBanner: false,
      theme: FlexThemeData.light(
        scheme: FlexScheme.mandyRed,
        useMaterial3: true,
        textTheme: textTheme,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.mandyRed,
        useMaterial3: true,
        textTheme: textTheme,
      ),
      themeMode: ThemeMode.system,
      home: const ScorePage(),
    );
  }
}
