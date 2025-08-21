import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importe o Firebase Auth

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    // Esconde o teclado
    FocusScope.of(context).unfocus();

    // Mostra o indicador de carregamento
    setState(() {
      _isLoading = true;
    });

    try {
      // Lógica de login com Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Se o login for bem-sucedido, o app irá para a próxima tela
      // (a lógica de navegação será adicionada depois)
    } on FirebaseAuthException catch (e) {
      // Trata erros de login
      String errorMessage = 'Ocorreu um erro, tente novamente.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Email ou senha inválidos.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'O formato do email é inválido.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // Esconde o indicador de carregamento
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definindo as cores baseadas na imagem
    final Color primaryColor = Color(0xFF0A2D4D); // Azul escuro do fundo
    final Color accentColor = Color(0xFF6B8D5A); // Verde do botão
    final Color textColor = Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Imagem de Fundo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  "assets/images/background.jpg",
                ), // Caminho da imagem
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 2. Overlay escuro para melhorar a legibilidade
          Container(color: primaryColor.withOpacity(0.6)),
          // 3. Conteúdo do Login
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Campo de Email
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          color: textColor.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: textColor.withOpacity(0.7),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: textColor),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16.0),
                    // Campo de Senha
                    TextField(
                      controller: _passwordController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: TextStyle(
                          color: textColor.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: textColor.withOpacity(0.7),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: textColor),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 32.0),
                    // Botão de Entrar
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
