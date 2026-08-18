import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const KinetosisApp());
}

class KinetosisApp extends StatelessWidget {
  const KinetosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetosis Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
