import 'package:cloud_firestore/cloud_firestore.dart';

class Ship {
  final String? id;
  final String name;
  final String client;
  final String product;
  final double quantity;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  Ship({
    this.id,
    required this.name,
    required this.client,
    required this.product,
    required this.quantity,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  // Converte um Documento do Firestore em um objeto Ship
  factory Ship.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Ship(
      id: doc.id,
      name: data['name'] ?? '',
      client: data['client'] ?? '',
      product: data['product'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'Programado',
    );
  }

  // Converte um objeto Ship em um Map para salvar no Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'client': client,
      'product': product,
      'quantity': quantity,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
    };
  }
}
