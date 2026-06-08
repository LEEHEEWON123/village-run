// flutter/lib/app.dart
import 'package:flutter/material.dart';
import 'features/splash/splash_screen.dart';

class VillageRunApp extends StatelessWidget {
  const VillageRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '내땅내밟',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
