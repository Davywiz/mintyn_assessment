import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'ui/visit_theme.dart';
import 'ui/visits_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VisitsApp()));
}

class VisitsApp extends StatelessWidget {
  const VisitsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'My visits',
    debugShowCheckedModeBanner: false,
    theme: visitTheme(),
    home: const VisitsScreen(),
  );
}
