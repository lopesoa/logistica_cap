import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logistica_cap/calendario/daily_operations_screen.dart';
import 'package:logistica_cap/ship/ships_list_screen.dart';

class AdminDrawer extends StatelessWidget {
  final VoidCallback onNavigateBack;
  const AdminDrawer({super.key, required this.onNavigateBack});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF0A2D4D), // Azul escuro do login
            ),
            child: Text(
              'Menu Administrador',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              // Fecha o menu
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Criar Usuários'),
            onTap: () {
              // Lógica para navegar para a tela de criação de usuários
              Navigator.pop(context);
              // Exemplo: Navigator.push(context, MaterialPageRoute(builder: (context) => CreateUserScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_boat),
            title: const Text('Cadastro de Navios'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShipsListScreen(),
                ),
              );
              onNavigateBack();
            },
          ),
          ListTile(
            // Adicione este ListTile
            leading: const Icon(Icons.calendar_today),
            title: const Text('Agenda de Operações'),
            onTap: () async {
              Navigator.pop(context); // Fecha o menu
              await Navigator.push(
                // "Espera" a tela de agenda fechar
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyOperationsScreen(),
                ),
              );
              onNavigateBack(); // 3. Chama a função para recarregar os dados!
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              // Implementar a lógica de logout se necessário aqui também
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}
