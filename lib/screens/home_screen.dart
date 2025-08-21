import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logistica_cap/calendario/daily_operation_model.dart';
import 'package:logistica_cap/ship/ship_model.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logistica_cap/widgets/admin_drawer.dart';
import 'package:logistica_cap/widgets/app_background.dart';
import 'package:table_calendar/table_calendar.dart';

// Definindo um tipo para o resultado da nossa busca
typedef DashboardTotals = ({
  Map<int, double> monthlyTotals,
  Map<int, double> previousYearsTotals,
});

Future<DashboardTotals>? _totalsFuture;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoading = true;
  // --- NOVAS VARIÁVEIS DE ESTADO PARA O CALENDÁRIO ---
  late final ValueNotifier<List<DailyOperation>> _selectedEvents;
  Map<DateTime, List<DailyOperation>> _calendarEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR');
    _loadUserData();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    //_fetchCalendarEvents(_focusedDay);

    // A primeira carga de dados acontece aqui
    _refreshData();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  void _refreshData() {
    // Força a recarga dos dados do calendário e dos totais
    _fetchCalendarEvents(_focusedDay);
    setState(() {
      _totalsFuture = _fetchDashboardTotals(DateTime.now().year);
    });
  }

  // --- NOVAS FUNÇÕES PARA O CALENDÁRIO ---
  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<DailyOperation> _getEventsForDay(DateTime day) {
    return _calendarEvents[_normalizeDate(day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents.value = _getEventsForDay(selectedDay);
      });
    }
  }

  void _fetchCalendarEvents(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final startRange = startOfMonth.subtract(const Duration(days: 7));
    final endRange = endOfMonth.add(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('daily_operations')
        .where('date', isGreaterThanOrEqualTo: startRange)
        .where('date', isLessThan: endRange)
        .get();

    final Map<DateTime, List<DailyOperation>> events = {};
    for (var doc in snapshot.docs) {
      final op = DailyOperation.fromFirestore(doc);
      final dateKey = _normalizeDate(op.date);
      if (events[dateKey] == null) {
        events[dateKey] = [];
      }
      events[dateKey]!.add(op);
    }

    setState(() {
      _calendarEvents = events;
      // Atualiza os eventos para o dia já selecionado
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['role'] == 'admin') {
        setState(() => _isAdmin = true);
      }
    } catch (e) {
      print("Erro ao buscar dados do usuário: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- WIDGETS DE COMPONENTES ---

  // --- WIDGET DO CALENDÁRIO ATUALIZADO ---
  Widget _buildCalendar() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar<DailyOperation>(
          locale: 'pt_BR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,

          // --- ALTERAÇÃO 1: Aumentando a altura da linha ---
          rowHeight:
              80, // O valor padrão é em torno de 52. Sinta-se à vontade para ajustar.

          daysOfWeekHeight: 40,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _fetchCalendarEvents(focusedDay);
          },
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            defaultTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ), // Aumentei um pouco a fonte
            weekendTextStyle: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
          ),
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) {
              final text = DateFormat.E('pt_BR').format(day).toUpperCase();
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE6A525),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF0A2D4D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: events
                    .map(
                      (op) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Icon(
                          op.type == 'RECEPCAO'
                              ? Icons.local_shipping
                              : Icons.directions_boat,
                          color: op.type == 'RECEPCAO'
                              ? Colors.orangeAccent.shade100
                              : Colors.lightBlueAccent.shade100,
                          // --- ALTERAÇÃO 2: Aumentando o tamanho dos ícones ---
                          size: 30, // Aumentamos de 18 para 22
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmbarcandoCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ships')
          .where('status', isEqualTo: 'Operando')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();
        final ship = Ship.fromFirestore(snapshot.data!.docs.first);
        final formatter = NumberFormat("#,##0.000", "pt_BR");
        return Card(
          color: const Color(0xFF388E3C),
          margin: const EdgeInsets.all(16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EMBARCANDO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ship.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatter.format(ship.quantity)}t - ${ship.product}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovimentacaoNavios(DateTime startOfMonth, DateTime endOfMonth) {
    final headerStyle = const TextStyle(
      color: Color(0xFF0A2D4D),
      fontWeight: FontWeight.bold,
    );

    // 1. Usamos um SizedBox para fixar a altura, igual à do Totalizador
    return SizedBox(
      height: 600, // Mesma altura do _buildTotalizadorAnual
      // 2. Usamos o Card como container principal para ter a borda
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blueGrey.shade300, width: 2),
        ),
        margin: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3. O título agora fica DENTRO do Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              color: const Color(
                0xFF0A2D4D,
              ).withOpacity(0.5), // Cor azul escura, igual ao tema
              child: Text(
                'MOVIMENTAÇÃO DE NAVIOS',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // 4. A área da tabela agora é rolável e ocupa o espaço restante
            Expanded(
              child: SingleChildScrollView(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ships')
                      .where('endDate', isGreaterThanOrEqualTo: startOfMonth)
                      .where('endDate', isLessThan: endOfMonth)
                      .orderBy('endDate')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Nenhuma movimentação para este mês.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );

                    final ships = snapshot.data!.docs
                        .map((doc) => Ship.fromFirestore(doc))
                        .toList();
                    final numberFormatter = NumberFormat("#,##0.000", "pt_BR");
                    final dateFormatter = DateFormat('dd/MM');

                    return DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFE6A525),
                      ),
                      headingTextStyle: headerStyle,
                      columnSpacing: 16,
                      horizontalMargin: 12,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight:
                          60, // Permite que o nome do navio quebre em 2 linhas
                      columns: const [
                        DataColumn(label: Text('NAVIO')),
                        DataColumn(label: Text('DATA')),
                        DataColumn(label: Text('CLIENTE')),
                        DataColumn(label: Text('QTDE')),
                        DataColumn(label: Text('PRODUTO')),
                      ],
                      rows: ships.map((ship) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                ship.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${dateFormatter.format(ship.startDate)} - ${dateFormatter.format(ship.endDate)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            DataCell(
                              Text(
                                ship.client,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            DataCell(
                              Text(
                                numberFormatter.format(ship.quantity),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            DataCell(
                              Text(
                                ship.product,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalizadorAnual(int year) {
    // Envolvemos o Card com um SizedBox para dar uma altura fixa.
    return SizedBox(
      height: 600, // Altura máxima que acomoda todos os meses e anos
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blueGrey.shade300, width: 2),
        ),
        margin: const EdgeInsets.all(0),
        // Adicionamos o SingleChildScrollView para o caso de o conteúdo estourar
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<DashboardTotals>(
              future: _totalsFuture, // Passando o ano para a função
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                if (snapshot.hasError || !snapshot.hasData) {
                  print(snapshot.error);
                  return const Text(
                    'Não foi possível carregar os totais.',
                    style: TextStyle(color: Colors.white70),
                  );
                }

                final totals = snapshot.data!;
                final monthlyTotals = totals.monthlyTotals;
                final previousYearsTotals = totals.previousYearsTotals;
                final yearTotal = monthlyTotals.values.reduce(
                  (sum, element) => sum + element,
                );

                final int currentMonth = (year == DateTime.now().year)
                    ? DateTime.now().month
                    : 12;
                List<Widget> monthWidgets = List.generate(currentMonth, (
                  index,
                ) {
                  final month = index + 1;
                  final monthName = DateFormat(
                    'MMMM',
                    'pt_BR',
                  ).format(DateTime(year, month)).toUpperCase();
                  return _buildTotalRow(monthName, monthlyTotals[month]!);
                });

                List<Widget> previousYearsWidgets = [];
                final sortedYears = previousYearsTotals.keys.toList()..sort();
                for (var yearItem in sortedYears) {
                  previousYearsWidgets.add(
                    _buildTotalRow(
                      yearItem.toString(),
                      previousYearsTotals[yearItem]!,
                      isPreviousYear: true,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMBARQUES ${year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...monthWidgets,
                    const Divider(color: Colors.white54, height: 24),
                    _buildTotalRow('TOTAL', yearTotal, isGrandTotal: true),
                    if (previousYearsWidgets.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ...previousYearsWidgets,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Também precisamos ajustar a função que busca os dados para receber o ano
  Future<DashboardTotals> _fetchDashboardTotals(int year) async {
    // ... (a lógica interna da função continua a mesma, apenas agora ela usa o 'year' recebido)
    final int currentYear = DateTime.now().year;
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year + 1, 1, 1);
    final monthlySnapshot = await FirebaseFirestore.instance
        .collection('ships')
        .where('status', isEqualTo: 'Finalizado')
        .where('endDate', isGreaterThanOrEqualTo: startOfYear)
        .where('endDate', isLessThan: endOfYear)
        .get();
    final Map<int, double> monthlyTotals = {
      for (var i = 1; i <= 12; i++) i: 0.0,
    };
    for (var doc in monthlySnapshot.docs) {
      final ship = Ship.fromFirestore(doc);
      final month = ship.endDate.month;
      monthlyTotals[month] = (monthlyTotals[month] ?? 0.0) + ship.quantity;
    }
    final Map<int, double> previousYearsTotals = {};
    List<Future> previousYearsFutures = [];
    for (int yearToFetch = 2022; yearToFetch < currentYear; yearToFetch++) {
      previousYearsFutures.add(
        FirebaseFirestore.instance
            .collection('ships')
            .where('status', isEqualTo: 'Finalizado')
            .where(
              'endDate',
              isGreaterThanOrEqualTo: DateTime(yearToFetch, 1, 1),
            )
            .where('endDate', isLessThan: DateTime(yearToFetch + 1, 1, 1))
            .get()
            .then((snapshot) {
              double total = 0;
              for (var doc in snapshot.docs) {
                total += (doc.data()['quantity'] ?? 0).toDouble();
              }
              previousYearsTotals[yearToFetch] = total;
            }),
      );
    }
    await Future.wait(previousYearsFutures);
    return (
      monthlyTotals: monthlyTotals,
      previousYearsTotals: previousYearsTotals,
    );
  }

  Widget _buildTotalRow(
    String label,
    double total, {
    bool isGrandTotal = false,
    bool isPreviousYear = false,
  }) {
    /* ...código existente, sem alterações... */
    final formatter = NumberFormat("#,##0.000", "pt_BR");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isPreviousYear
                  ? Colors.lightBlue.shade300
                  : Colors.white.withOpacity(0.9),
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            formatter.format(total),
            style: TextStyle(
              color: isPreviousYear
                  ? Colors.greenAccent.shade400
                  : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- NOVO WIDGET para o cabeçalho customizado ---
  Widget _buildHeader(BuildContext context) {
    final monthName = DateFormat(
      'MMMM',
      'pt_BR',
    ).format(DateTime.now()).toUpperCase();
    // Lógica para criar o botão de menu ou um espaço vazio
    Widget menuTrigger;
    if (_isAdmin) {
      // Se for admin, cria um botão de menu clicável
      menuTrigger = IconButton(
        icon: const Icon(Icons.menu, color: Colors.white, size: 30),
        tooltip: 'Abrir menu',
        onPressed: () {
          // Comando para abrir o menu lateral (Drawer)
          Scaffold.of(context).openDrawer();
        },
      );
    } else {
      // Se não for admin, cria um espaço vazio com a mesma largura
      menuTrigger = const SizedBox(
        width: 56,
      ); // Largura padrão de um IconButton
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Coluna da Esquerda: O novo botão de menu
          menuTrigger,

          // Título Central
          Expanded(
            child: Text(
              'PROGRAMAÇÃO ${monthName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Ícones e Ano (Direita)
          Row(
            children: [
              const Icon(Icons.directions_boat, color: Colors.white, size: 30),
              const SizedBox(width: 8),
              const Icon(Icons.local_shipping, color: Colors.white, size: 30),
              const SizedBox(width: 16),
              Text(
                DateTime.now().year.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Placeholder ATUALIZADO para parecer uma tabela vazia ---
  Widget _buildPlaceholder(String title, List<String> headers) {
    return Card(
      color: Colors.transparent, // Fundo transparente
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey.shade700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          // Cabeçalho da Tabela
          Container(
            color: const Color(0xFFE6A525), // Dourado
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: headers
                  .map(
                    (h) => Expanded(
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0A2D4D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Espaço para o conteúdo
          const SizedBox(height: 100),
          Center(
            child: Text(
              '(Fase 2)',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- MÉTODO BUILD FINAL COM O LAYOUT CORRETO ---
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    return AppBackground(
      child: Scaffold(
        drawer: _isAdmin ? AdminDrawer(onNavigateBack: _refreshData) : null,

        // Usaremos um cabeçalho customizado em vez do AppBar
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  Builder(
                    builder: (context) {
                      // Este 'context' é a chave!
                      return _buildHeader(context);
                    },
                  ), // Cabeçalho customizado
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // --- LINHA 1 ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // COLUNA 1.1: Calendário
                              Expanded(flex: 4, child: _buildCalendar()),
                              const SizedBox(width: 16),
                              // COLUNA 1.2: Movimentação de Navios
                              Expanded(
                                flex: 5,
                                child: _buildMovimentacaoNavios(
                                  startOfMonth,
                                  endOfMonth,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // COLUNA 1.3: Totais
                              Expanded(
                                flex: 3,
                                child: _buildTotalizadorAnual(now.year),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // --- LINHA 2 ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // COLUNA 2.1: Line-up 201
                              Expanded(
                                flex: 4,
                                child: _buildPlaceholder('LINE-UP 201', [
                                  'NAVIO',
                                  'PRODUTO',
                                  'ETA',
                                  'QTDE',
                                ]),
                              ),
                              const SizedBox(width: 16),
                              // COLUNA 2.2: Line-up Leste
                              Expanded(
                                flex: 3,
                                child: _buildPlaceholder(
                                  'LINE-UP LESTE E PESTA',
                                  ['SITUAÇÃO', 'QTDE'],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // COLUNA 2.3: Embarcando
                              Expanded(flex: 3, child: _buildEmbarcandoCard()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
