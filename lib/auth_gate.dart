import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logistica_cap/screens/home_screen.dart';
import 'package:logistica_cap/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Se não tiver um usuário logado, mostra a tela de login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Se tiver um usuário logado, mostra a tela principal
        return const HomeScreen();
      },
    );
  }
}
