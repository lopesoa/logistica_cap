import 'package:flutter/material.dart';
import 'package:logistica_cap/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child; // O conteúdo da tela (o que vai ficar na frente do fundo)

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Imagem de Fundo
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/background.jpg"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // 2. Overlay escuro para melhorar a legibilidade
        Container(color: AppTheme.primaryColor.withOpacity(0.6)),
        // 3. O conteúdo da tela que foi passado para o widget
        child,
      ],
    );
  }
}
