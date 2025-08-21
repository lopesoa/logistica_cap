import 'package:flutter/material.dart';

class AppTheme {
  // Nossas cores principais
  static const Color primaryColor = Color(0xFF0A2D4D); // Azul escuro
  static const Color accentColor = Color(0xFF6B8D5A); // Verde
  static const Color textColor = Colors.white;

  // Método que retorna o tema completo do App
  static ThemeData getTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors
          .transparent, // Fundo do scaffold transparente para o background aparecer
      // Tema do AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0, // Sem sombra
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: textColor,
        ), // Cor dos ícones (menu, sair)
      ),

      // Tema dos botões
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: textColor, // Cor do texto do botão
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),

      // Cor de destaque (usada em vários lugares)
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
      ).copyWith(secondary: accentColor),
    );
  }
}
