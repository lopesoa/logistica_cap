import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logistica_cap/app_theme.dart';
import 'firebase_options.dart';
import 'package:logistica_cap/auth_gate.dart'; // Importe o AuthGate

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Logística CAP',
      theme: AppTheme.getTheme(), // <<< APLIQUE O TEMA AQUI
      home: const AuthGate(),
    );
  }
}
