import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logistica_cap/ship/ship_model.dart';
import 'package:intl/intl.dart';
import 'package:logistica_cap/widgets/app_background.dart';

class ShipFormScreen extends StatefulWidget {
  final Ship? ship; // Navio opcional para modo de edição

  const ShipFormScreen({super.key, this.ship});

  @override
  _ShipFormScreenState createState() => _ShipFormScreenState();
}

class _ShipFormScreenState extends State<ShipFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _clientController;
  late TextEditingController _productController;
  late TextEditingController _quantityController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  String? _selectedStatus;

  final List<String> _statusOptions = ['Operando', 'Finalizado'];

  @override
  void initState() {
    super.initState();
    // Preenche os campos se estiver no modo de edição
    _nameController = TextEditingController(text: widget.ship?.name ?? '');
    _clientController = TextEditingController(text: widget.ship?.client ?? '');
    _productController = TextEditingController(
      text: widget.ship?.product ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.ship?.quantity.toString() ?? '',
    );
    _startDateController = TextEditingController(
      text: widget.ship != null
          ? DateFormat('dd/MM/yyyy').format(widget.ship!.startDate)
          : '',
    );
    _endDateController = TextEditingController(
      text: widget.ship != null
          ? DateFormat('dd/MM/yyyy').format(widget.ship!.endDate)
          : '',
    );
    _selectedStatus = widget.ship?.status ?? 'Operando';
  }

  // Função para abrir o seletor de data
  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _saveShip() async {
    if (_formKey.currentState!.validate()) {
      try {
        final formatter = DateFormat('dd/MM/yyyy');

        // --- A CORREÇÃO ESTÁ AQUI ---
        // 1. Pegamos o texto do campo de quantidade.
        // 2. Usamos .replaceAll(',', '.') para trocar a vírgula por ponto.
        final quantityText = _quantityController.text.replaceAll(',', '.');

        final newShip = Ship(
          id: widget.ship?.id,
          name: _nameController.text,
          client: _clientController.text,
          product: _productController.text,
          quantity: double.parse(
            quantityText,
          ), // 3. Agora usamos o texto corrigido.
          startDate: formatter.parse(_startDateController.text),
          endDate: formatter.parse(_endDateController.text),
          status: _selectedStatus!,
        );

        final collection = FirebaseFirestore.instance.collection('ships');

        if (widget.ship == null) {
          // Criar novo
          await collection.add(newShip.toFirestore());
        } else {
          // Atualizar existente
          await collection.doc(newShip.id).update(newShip.toFirestore());
        }

        if (mounted) Navigator.pop(context); // Volta para a lista
      } catch (e) {
        // Mostra um erro mais amigável
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao salvar: Verifique os valores inseridos. ($e)',
            ),
          ),
        );
      }
    }
  }

  void _deleteShip() async {
    if (widget.ship != null) {
      await FirebaseFirestore.instance
          .collection('ships')
          .doc(widget.ship!.id)
          .delete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.ship == null ? 'Adicionar Navio' : 'Editar Navio'),
          actions: [
            if (widget.ship != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteShip,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextFormField(_nameController, 'Nome do Navio'),
                _buildTextFormField(_clientController, 'Cliente'),
                _buildTextFormField(_productController, 'Produto'),
                _buildTextFormField(
                  _quantityController,
                  'Quantidade',
                  keyboardType: TextInputType.number,
                ),
                _buildDateField(_startDateController, 'Data de Início'),
                _buildDateField(_endDateController, 'Data de Fim'),
                _buildStatusDropdown(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveShip,
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        readOnly: true,
        onTap: () => _selectDate(context, controller),
        validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        dropdownColor: const Color(0xFF0A2D4D),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Status',
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        items: _statusOptions.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedStatus = newValue;
          });
        },
        validator: (value) => value == null ? 'Campo obrigatório' : null,
      ),
    );
  }
}
