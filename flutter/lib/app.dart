// flutter/lib/app.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_screen.dart';

// MapScreen stub — will be replaced in Task 7
class MapScreenStub extends StatelessWidget {
  const MapScreenStub({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Map Screen (coming soon)')),
  );
}

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
        '/map': (_) => const MapScreenStub(),
      },
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginScreen()
          : const MapScreenStub(),
    );
  }
}
