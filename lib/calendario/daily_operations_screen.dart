import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logistica_cap/calendario/daily_operation_model.dart';
import 'package:logistica_cap/widgets/app_background.dart';

class DailyOperationsScreen extends StatefulWidget {
  const DailyOperationsScreen({super.key});

  @override
  State<DailyOperationsScreen> createState() => _DailyOperationsScreenState();
}

class _DailyOperationsScreenState extends State<DailyOperationsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _typeFilter = 'TODOS'; // TODOS, RECEPCAO, EXPEDICAO

  @override
  void initState() {
    super.initState();
    // Inicia o filtro com o mês atual para uma visão mais focada
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  // Função para normalizar a data para o início do dia (ignorar horas/minutos)
  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // Função para adicionar um novo dia à lista
  Future<void> _addNewDay() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final normalizedDate = _normalizeDate(pickedDate);
      // Verifica se já existe alguma operação para este dia e tipo
      final query = await FirebaseFirestore.instance
          .collection('daily_operations')
          .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
          .where('type', isEqualTo: 'RECEPCAO')
          .limit(1)
          .get();

      // Se não existir, cria uma operação padrão de Recepção para fazer o dia aparecer
      if (query.docs.isEmpty) {
        final newOp = DailyOperation(date: normalizedDate, type: 'RECEPCAO');
        await FirebaseFirestore.instance
            .collection('daily_operations')
            .add(newOp.toFirestore());
      }
    }
  }

  // Lógica para marcar/desmarcar uma operação
  void _toggleOperation(
    DateTime date,
    String type,
    bool isChecked,
    List<DailyOperation> allOps,
  ) {
    final normalizedDate = _normalizeDate(date);

    if (isChecked) {
      // Se marcou, cria um novo documento
      final newOp = DailyOperation(date: normalizedDate, type: type);
      FirebaseFirestore.instance
          .collection('daily_operations')
          .add(newOp.toFirestore());
    } else {
      // Se desmarcou, encontra o documento existente e o apaga
      final opToDelete = allOps.firstWhere(
        (op) => _normalizeDate(op.date) == normalizedDate && op.type == type,
      );
      if (opToDelete.id != null) {
        FirebaseFirestore.instance
            .collection('daily_operations')
            .doc(opToDelete.id)
            .delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Agenda Interativa')),
        body: Column(
          children: [
            // --- BARRA DE FILTROS ---
            _buildFilterBar(),

            // --- LISTA DE OPERAÇÕES ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('daily_operations')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma operação agendada.",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final allOps = snapshot.data!.docs
                      .map((doc) => DailyOperation.fromFirestore(doc))
                      .toList();

                  // Aplica os filtros
                  final filteredOps = allOps.where((op) {
                    final normalizedOpDate = _normalizeDate(op.date);
                    final isAfterStartDate =
                        _startDate == null ||
                        !normalizedOpDate.isBefore(_normalizeDate(_startDate!));
                    final isBeforeEndDate =
                        _endDate == null ||
                        !normalizedOpDate.isAfter(_normalizeDate(_endDate!));
                    final matchesType =
                        _typeFilter == 'TODOS' || op.type == _typeFilter;
                    return isAfterStartDate && isBeforeEndDate && matchesType;
                  }).toList();

                  // Agrupa as operações por dia
                  final Map<DateTime, List<DailyOperation>> groupedOps = {};
                  for (var op in filteredOps) {
                    final dateKey = _normalizeDate(op.date);
                    if (groupedOps[dateKey] == null) {
                      groupedOps[dateKey] = [];
                    }
                    groupedOps[dateKey]!.add(op);
                  }

                  if (groupedOps.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma operação encontrada para os filtros selecionados.",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final sortedKeys = groupedOps.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView.builder(
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final date = sortedKeys[index];
                      final opsForDay = groupedOps[date]!;

                      final hasReception = opsForDay.any(
                        (op) => op.type == 'RECEPCAO',
                      );
                      final hasExpedition = opsForDay.any(
                        (op) => op.type == 'EXPEDICAO',
                      );

                      return Card(
                        color: Colors.white.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'EEEE, dd \'de\' MMMM \'de\' yyyy',
                                  'pt_BR',
                                ).format(date),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Divider(color: Colors.white24),
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: const Text(
                                        'Recepção 🚚',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      value: hasReception,
                                      onChanged: (bool? value) {
                                        _toggleOperation(
                                          date,
                                          'RECEPCAO',
                                          value!,
                                          allOps,
                                        );
                                      },
                                      activeColor: Colors.orangeAccent,
                                      checkColor: Colors.black,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                  ),
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: const Text(
                                        'Expedição 🚢',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      value: hasExpedition,
                                      onChanged: (bool? value) {
                                        _toggleOperation(
                                          date,
                                          'EXPEDICAO',
                                          value!,
                                          allOps,
                                        );
                                      },
                                      activeColor: Colors.lightBlueAccent,
                                      checkColor: Colors.black,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewDay,
          tooltip: 'Adicionar novo dia à agenda',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    /* ...código existente, sem alterações... */
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.date_range_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        _startDate == null
                            ? 'Início'
                            : DateFormat('dd/MM/yy').format(_startDate!),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2022),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                    ),
                  ),
                  const Text("-", style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.date_range_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        _endDate == null
                            ? 'Fim'
                            : DateFormat('dd/MM/yy').format(_endDate!),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2022),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.redAccent),
                    tooltip: "Limpar filtros",
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                      _typeFilter = 'TODOS';
                    }),
                  ),
                ],
              ),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  selectedForegroundColor: Colors.black,
                  selectedBackgroundColor: Colors.white,
                ),
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'TODOS', label: Text('Todos')),
                  ButtonSegment<String>(
                    value: 'RECEPCAO',
                    icon: Icon(Icons.local_shipping),
                  ),
                  ButtonSegment<String>(
                    value: 'EXPEDICAO',
                    icon: Icon(Icons.directions_boat),
                  ),
                ],
                selected: {_typeFilter},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _typeFilter = newSelection.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
