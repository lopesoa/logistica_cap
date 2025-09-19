import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logistica_cap/calendario/daily_operation_model.dart';
import 'package:logistica_cap/ship/ship_model.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logistica_cap/widgets/admin_drawer.dart';
import 'package:logistica_cap/widgets/app_background.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http; // Importe o pacote http
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

// Definindo um tipo para o resultado da nossa busca
typedef DashboardTotals = ({
  Map<int, double> monthlyTotals,
  Map<int, double> previousYearsTotals,
});

class LineupItem {
  final Map<String, dynamic> data;
  String terminal;
  LineupItem({required this.data, this.terminal = ''});
}

Future<DashboardTotals>? _totalsFuture;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  bool _isAdmin = false;
  bool _isLoading = true;
  // --- NOVAS VARIÁVEIS DE ESTADO PARA O CALENDÁRIO ---
  late final ValueNotifier<List<DailyOperation>> _selectedEvents;
  Map<DateTime, List<DailyOperation>> _calendarEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<List<dynamic>> _lineupFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR');
    _loadUserData();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    //_fetchCalendarEvents(_focusedDay);
    windowManager.addListener(this);
    // A primeira carga de dados acontece aqui
    _refreshData();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() async {
    // Entra em modo de tela cheia quando a janela é maximizada
    await windowManager.setFullScreen(true);
  }

  @override
  void onWindowUnmaximize() async {
    // Sai do modo de tela cheia quando a janela é restaurada
    await windowManager.setFullScreen(false);
  }

  void _refreshData() {
    // Força a recarga dos dados do calendário e dos totais
    _fetchCalendarEvents(_focusedDay);
    setState(() {
      _totalsFuture = _fetchDashboardTotals(DateTime.now().year);
      _lineupFuture = _fetchLineupData();
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
      if (mounted) setState(() => _isLoading = false);
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
              65, // O valor padrão é em torno de 52. Sinta-se à vontade para ajustar.

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
                          size: 25, // Aumentamos de 18 para 22
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
        final formatter = NumberFormat("#,##0", "pt_BR");
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
                      .where('status', isEqualTo: 'Finalizado')
                      .where('endDate', isGreaterThanOrEqualTo: startOfMonth)
                      .where('endDate', isLessThan: endOfMonth)
                      .orderBy('endDate')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Nenhuma movimentação para este mês.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }

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
          primary: false,
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
      // Se for admin, cria o logo clicável
      menuTrigger = InkWell(
        onTap: () {
          // Comando para abrir o menu lateral (Drawer)
          Scaffold.of(context).openDrawer();
        },
        child: Image.asset(
          'assets/images/logo.png',
          width: 80, // Ajuste o tamanho conforme necessário
          height: 70,
        ),
      );
    } else {
      // Se não for admin, exibe apenas o logo sem a funcionalidade de clique
      menuTrigger = Image.asset(
        'assets/images/logo.png',
        width: 40, // Use a mesma largura para manter o layout
        height: 40,
      );
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

  Future<List<dynamic>> _fetchLineupData() async {
    final lineupFunctionUrl = Uri.parse(
      "https://us-central1-logistica-cap.cloudfunctions.net/getLineupData?type=retroativo",
    );
    try {
      if (!kIsWeb && !Platform.isWindows) {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final result = await functions.httpsCallable('getLineupData').call();
        return List<dynamic>.from(result.data);
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("Usuário não logado.");
        final idToken = await currentUser.getIdToken();
        final response = await http.post(
          lineupFunctionUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'data': {}}),
        );
        if (response.statusCode == 200) {
          final body = json.decode(response.body);
          return List<dynamic>.from(body['result']);
        } else {
          throw Exception('Falha ao carregar Line-up: ${response.body}');
        }
      }
    } catch (e) {
      print("Erro ao chamar a Cloud Function: $e");
      rethrow;
    }
  }

  // Widget para o Line-up 201, agora usando o molde e com a rolagem corrigida
  Widget _buildLineup201(Future<List<dynamic>> future) {
    return _Lineup201Widget(
      future: future,
    ); // Usando um widget separado para gerenciar seu próprio estado
  }

  // Widget para o Totalizador dos outros berços, agora com o estilo e dados corretos
  Widget _buildLineupOutrosBercos(Future<List<dynamic>> future) {
    return GenericCard(
      title: 'LINE-UP LESTE E PASA',
      headers: ['SITUAÇÃO', 'PRODUTO', 'QTDE'],
      content: LayoutBuilder(
        // <<-- Coloque o LayoutBuilder aqui
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight, // Use a altura máxima do GenericCard
            child: FutureBuilder<List<dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(
                    child: Text(
                      'Erro',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final List<String> outrosBercos = ['212', '213', '214'];
                final items = snapshot.data!
                    .where((item) => outrosBercos.contains(item['berco']))
                    .toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum item',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final Map<String, Map<String, int>> aglutinador = {};
                for (var item in items) {
                  String status = item['status'];
                  String produto = item['produto'];
                  aglutinador.putIfAbsent(status, () => {});
                  aglutinador[status]!.putIfAbsent(produto, () => 0);
                  aglutinador[status]![produto] =
                      aglutinador[status]![produto]! + 1;
                }

                final statusOrder = [
                  "ATRACADOS",
                  "PROGRAMADOS",
                  "AO LARGO",
                  "ESPERADOS",
                ];
                List<Map<String, dynamic>> finalRows = [];
                for (var status in statusOrder) {
                  if (aglutinador.containsKey(status)) {
                    aglutinador[status]!.forEach((produto, count) {
                      finalRows.add({
                        'status': status,
                        'produto': produto,
                        'count': count,
                      });
                    });
                  }
                }

                return ListView.builder(
                  itemCount: finalRows.length,
                  itemBuilder: (context, index) {
                    final rowData = finalRows[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 6.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rowData['status'],
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rowData['produto'],
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rowData['count'].toString(),
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Adicione esta nova função em _HomeScreenState
  Widget _buildPrevistoCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ships')
          .where('status', isEqualTo: 'Previsto')
          .orderBy('startDate')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Não mostra nada se não houver
        }
        final ship = Ship.fromFirestore(snapshot.data!.docs.first);
        final formatter = DateFormat('dd/MM HH:mm');
        final numberFormatter = NumberFormat("#,##0", "pt_BR");

        return Card(
          color: Colors.amber.shade800, // Cor amarela/laranja
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PREVISTO',
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
                  '${numberFormatter.format(ship.quantity)}t - ${ship.product}',
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

  // --- MÉTODO BUILD FINAL COM O LAYOUT CORRETO ---
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    const double headerHeight = 70.0;
    return AppBackground(
      child: Scaffold(
        drawer: _isAdmin ? AdminDrawer(onNavigateBack: _refreshData) : null,

        // Usaremos um cabeçalho customizado em vez do AppBar
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : RawKeyboardListener(
                focusNode: FocusNode(),
                autofocus: true,
                onKey: (event) async {
                  if (event is RawKeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.f11) {
                      // Verifique o estado atual e alterne
                      final isCurrentlyFullScreen = await windowManager
                          .isFullScreen();
                      await windowManager.setFullScreen(!isCurrentlyFullScreen);
                    }
                  }
                },
                child: Column(
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
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).size.height -
                              headerHeight -
                              40,
                          child: Column(
                            children: [
                              // --- LINHA 1 ---
                              Expanded(
                                flex: 6, // 60%
                                child: Row(
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
                              ),
                              const SizedBox(height: 16),
                              // --- LINHA 2 ---
                              Expanded(
                                flex: 4,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // COLUNA 2.1: Line-up 201
                                    Expanded(
                                      flex: 6,
                                      child: _buildLineup201(_lineupFuture),
                                    ),
                                    const SizedBox(width: 16),
                                    // COLUNA 2.2: Line-up Outros Berços
                                    Expanded(
                                      flex: 3,
                                      child: _buildLineupOutrosBercos(
                                        _lineupFuture,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // COLUNA 2.3: Embarcando
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildEmbarcandoCard(),
                                          _buildPrevistoCard(), // Adicionado aqui
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// --- WIDGET SEPARADO PARA O LINE-UP 201 ---
class _Lineup201Widget extends StatefulWidget {
  final Future<List<dynamic>> future;
  const _Lineup201Widget({required this.future});

  @override
  State<_Lineup201Widget> createState() => _Lineup201WidgetState();
}

class _Lineup201WidgetState extends State<_Lineup201Widget> {
  Future<List<LineupItem>> _fetchAndMergeData() async {
    final lineupRaw = await widget.future;

    // --- PASSO DE DEBUG ---
    // Vamos imprimir a lista completa que recebemos da Cloud Function
    print("--- DADOS BRUTOS DO LINEUP RECEBIDOS ---");
    for (var item in lineupRaw) {
      print(item);
    }
    print("--- FIM DOS DADOS BRUTOS ---");
    // ----------------------

    final items201 = lineupRaw.where((item) {
      // Verificação mais segura do tipo
      return item['berco']?.toString() == '201';
    }).toList();

    // --- PASSO DE DEBUG 2 ---
    print("Itens encontrados para o Berço 201: ${items201.length}");
    // ------------------------

    List<LineupItem> mergedList = [];
    for (var itemData in items201) {
      final prog = itemData['program']?.toString();
      if (prog != null && prog.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('lineup_metadata')
            .doc(prog)
            .get();
        String terminalValue = '';
        if (doc.exists) {
          terminalValue = doc.data()?['terminal'] ?? '';
        }
        mergedList.add(LineupItem(data: itemData, terminal: terminalValue));
      }
    }
    return mergedList;
  }

  void _showEditTerminalDialog(LineupItem item) {
    final terminalController = TextEditingController(text: item.terminal);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar Terminal para ${item.data['navio']}'),
          content: TextField(
            controller: terminalController,
            decoration: const InputDecoration(labelText: 'Terminal'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prog = item.data['program']?.toString();
                if (prog != null && prog.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('lineup_metadata')
                      .doc(prog)
                      .set({
                        'terminal': terminalController.text,
                      }, SetOptions(merge: true));
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GenericCard(
      title: 'LINE-UP 201',
      headers: [
        'NAVIO',
        'PRODUTO',
        'ETA',
        'QUANTIDADE',
        'SENTIDO',
        'SITUAÇÃO',
        'TERMINAL',
      ],
      content: FutureBuilder<List<LineupItem>>(
        future: _fetchAndMergeData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum item',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => _showEditTerminalDialog(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.data['navio'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.data['produto'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.data['eta'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          // 1. Cria o formatador para o padrão brasileiro de milhar (sem decimais)
                          NumberFormat('#,##0', 'pt_BR').format(
                            // 2. Converte seu dado para um inteiro
                            (item.data['qtd'] as num? ?? 0).toInt(),
                          ),
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.data['sentido'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.data['status'] ?? '',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.terminal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET GENÉRICOCARD (FORA DAS OUTRAS CLASSES) ---
class GenericCard extends StatelessWidget {
  final String title;
  final List<String> headers;
  final Widget content;
  const GenericCard({
    super.key,
    required this.title,
    required this.headers,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey.shade700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Container(
            color: const Color(0xFFE6A525),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: headers
                  .map(
                    (h) => Expanded(
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0A2D4D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
