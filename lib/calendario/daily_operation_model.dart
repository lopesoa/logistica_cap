import 'package:cloud_firestore/cloud_firestore.dart';

class DailyOperation {
  final String? id;
  final DateTime date;
  final String type; // 'RECEPCAO' ou 'EXPEDICAO'

  DailyOperation({this.id, required this.date, required this.type});

  factory DailyOperation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DailyOperation(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'date': Timestamp.fromDate(date), 'type': type};
  }
}
