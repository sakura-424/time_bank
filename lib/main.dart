import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main () {
  runApp(const TimeBankApp());
}

class TimeBankApp extends StatelessWidget {
  const TimeBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '10,000 Hours',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
