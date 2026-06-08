// flutter/lib/app.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_screen.dart';
import 'features/map/map_screen.dart';

class VillageRunApp extends StatelessWidget {
  const VillageRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Village Run',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
      ),
      routes: {
        '/map': (_) => const MapScreen(),
      },
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginScreen()
          : const MapScreen(),
    );
  }
}
