import 'package:flutter/material.dart';

import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ChordFlowApp());
}

/// Chord Flow — voicing e rivolti per fisarmonica, pensati per tenere la
/// "mano ferma": il minimo spostamento possibile tra un accordo e l'altro.
class ChordFlowApp extends StatelessWidget {
  const ChordFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chord Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgBottom,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brass,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
