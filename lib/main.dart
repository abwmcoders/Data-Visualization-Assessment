import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'viewmodels/biometrics_viewmodel.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(ChangeNotifierProvider(create: (_) => BiometricsViewModel(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometrics Dashboard',
      themeMode: ThemeMode.system,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: DashboardScreen(),
    );
  }
}

