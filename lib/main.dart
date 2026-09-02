import 'package:flutter/material.dart';
import 'package:plantcare_ai/constants/constants.dart';
import 'package:plantcare_ai/screens/homepage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PlantCare AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardTheme(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
