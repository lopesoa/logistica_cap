import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logistica_cap/ship/ship_form_screen.dart';
import 'package:logistica_cap/ship/ship_model.dart';
import 'package:intl/intl.dart';
import 'package:logistica_cap/widgets/app_background.dart';

// Convertemos para StatefulWidget para gerenciar o estado da busca
class ShipsListScreen extends StatefulWidget {
  const ShipsListScreen({super.key});

  @override
  State<ShipsListScreen> createState() => _ShipsListScreenState();
}

class _ShipsListScreenState extends State<ShipsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Escuta as alterações no campo de busca para atualizar a UI
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Função para criar o Chip de Status com cores
  Widget _getStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'Operando':
        chipColor = Colors.orangeAccent;
        break;
      case 'Finalizado':
        chipColor = Colors.green;
        break;
      case 'Atracado':
        chipColor = Colors.blueAccent;
        break;
      case 'Cancelado':
        chipColor = Colors.redAccent;
        break;
      default: // Programado
        chipColor = Colors.grey.shade600;
    }

    return Chip(
      label: Text(status),
      backgroundColor: chipColor,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Gerenciamento de Navios')),
        body: Column(
          children: [
            // BARRA DE PESQUISA
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Pesquisar por nome do navio...',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            // LISTA DE NAVIOS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ships')
                    .orderBy('startDate', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum navio cadastrado.',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    );
                  }

                  // Filtra os navios com base na busca
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final shipName =
                        (doc.data() as Map<String, dynamic>)['name']
                            ?.toString()
                            .toLowerCase() ??
                        '';
                    return shipName.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum navio encontrado.',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final ship = Ship.fromFirestore(filteredDocs[index]);
                      final formatter = DateFormat('dd/MM/yy');
                      return Card(
                        color: Colors.white.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          title: Text(
                            ship.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${ship.product} | ${formatter.format(ship.startDate)} a ${formatter.format(ship.endDate)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          trailing: _getStatusChip(
                            ship.status,
                          ), // Usando nosso novo Chip estilizado
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ShipFormScreen(ship: ship),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // BOTÃO DE ADICIONAR
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ShipFormScreen()),
            );
          },
          backgroundColor: Theme.of(
            context,
          ).colorScheme.secondary, // Verde do nosso tema
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
