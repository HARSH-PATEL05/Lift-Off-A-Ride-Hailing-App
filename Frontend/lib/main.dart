import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://opkjyfcbrxdnjsmcxwkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wa2p5ZmNicnhkbmpzbWN4d2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5MzcxNTEsImV4cCI6MjEwMTUxMzE1MX0.bi6KBoBfE5bpHUdyMthg8sDdbPnBkdE6WMLUX1MTFMw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> signIn() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LiftOff Auth Test"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: signIn,
          child: const Text("Continue with Google"),
        ),
      ),
    );
  }
}