import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:logistica_cap/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'firebase_options.dart';
import 'package:logistica_cap/auth_gate.dart'; // Importe o AuthGate
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- A CORREÇÃO ESTÁ AQUI ---
  // Só ativa o App Check se a plataforma NÃO for Windows0
  if (!kIsWeb && !Platform.isWindows) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      // Se você fosse dar suporte para Apple, adicionaria o appleProvider aqui
    );
  }

  await windowManager.ensureInitialized();

  /* // Configurações para a janela do Windows
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600), // Tamanho inicial da janela (opcional)
    center: true, // Centraliza a janela na tela
    backgroundColor: Colors.transparent, // Fundo transparente (opcional)
    skipTaskbar: false, // Se a janela vai aparecer na barra de tarefas
    titleBarStyle: TitleBarStyle.hidden, // Esconde a barra de título
  );

  // Configura a janela com as opções definidas acima
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  }); */
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
