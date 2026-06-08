// flutter/lib/app.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Stubs — will be replaced in Tasks 3 and 7
class _LoginScreenStub extends StatelessWidget {
  const _LoginScreenStub();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Login Screen (TODO)')),
  );
}

class _MapScreenStub extends StatelessWidget {
  const _MapScreenStub();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Map Screen (TODO)')),
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
      home: Supabase.instance.client.auth.currentSession == null
          ? const _LoginScreenStub()
          : const _MapScreenStub(),
    );
  }
}
