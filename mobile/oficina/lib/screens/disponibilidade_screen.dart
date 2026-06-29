import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/widgets.dart';

class DisponibilidadeScreen extends StatefulWidget {
  const DisponibilidadeScreen({super.key});

  @override
  State<DisponibilidadeScreen> createState() => _DisponibilidadeScreenState();
}

class _DisponibilidadeScreenState extends State<DisponibilidadeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Formulário de cadastro ────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _vagasCtrl = TextEditingController(text: '1');
  DateTime? _dataSelecionada;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;
  Map<String, dynamic>? _servicoSelecionado;

  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _disponibilidades = [];
  bool _carregando = false;
  bool _salvando = false;

  static const String _baseUrl = 'http://localhost:5000/api';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vagasCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final resServicos = await http.get(Uri.parse('$_baseUrl/servicos/'));
      final resDisp = await http.get(Uri.parse('$_baseUrl/disponibilidades/'));

      if (mounted) {
        setState(() {
          _servicos =
              List<Map<String, dynamic>>.from(jsonDecode(resServicos.body));
          _disponibilidades =
              List<Map<String, dynamic>>.from(jsonDecode(resDisp.body));
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final dt = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kOrange),
        ),
        child: child!,
      ),
    );
    if (dt != null) setState(() => _dataSelecionada = dt);
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: isInicio
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kOrange),
        ),
        child: child!,
      ),
    );
    if (hora != null) {
      setState(() {
        if (isInicio)
          _horaInicio = hora;
        else
          _horaFim = hora;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataSelecionada == null) {
      _snack('Selecione a data', erro: true);
      return;
    }
    if (_horaInicio == null || _horaFim == null) {
      _snack('Selecione os horários', erro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      final data = _dataSelecionada!;
      final res = await http.post(
        Uri.parse('$_baseUrl/disponibilidades/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data':
              '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}',
          'hora_inicio':
              '${_horaInicio!.hour.toString().padLeft(2, '0')}:${_horaInicio!.minute.toString().padLeft(2, '0')}',
          'hora_fim':
              '${_horaFim!.hour.toString().padLeft(2, '0')}:${_horaFim!.minute.toString().padLeft(2, '0')}',
          'vagas': int.parse(_vagasCtrl.text),
          if (_servicoSelecionado != null)
            'servico_id': _servicoSelecionado!['id'],
        }),
      );

      if (res.statusCode == 201) {
        _snack('Disponibilidade cadastrada!');
        setState(() {
          _dataSelecionada = null;
          _horaInicio = null;
          _horaFim = null;
          _servicoSelecionado = null;
          _vagasCtrl.text = '1';
        });
        _carregarDados();
        _tabController.animateTo(1); // vai para aba de listagem
      } else {
        final erro = jsonDecode(res.body)['erro'] ?? 'Erro ao salvar';
        _snack(erro, erro: true);
      }
    } catch (e) {
      _snack('Erro de conexão', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover disponibilidade'),
        content: const Text('Deseja remover este horário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await http.delete(Uri.parse('$_baseUrl/disponibilidades/$id'));
      _carregarDados();
    }
  }

  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilidades'),
        centerTitle: true,
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Cadastrar'),
            Tab(icon: Icon(Icons.list_alt), text: 'Cadastrados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormulario(),
          _buildListagem(),
        ],
      ),
    );
  }

  // ── Aba 1: Formulário ────────────────────────────────────
  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Serviço (opcional)
            _secao('Serviço vinculado (opcional)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _servicoSelecionado,
              decoration: _deco('Selecione um serviço', Icons.build_outlined),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Qualquer serviço'),
                ),
                ..._servicos.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                          '${s['nome']} — R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}'),
                    )),
              ],
              onChanged: (v) => setState(() => _servicoSelecionado = v),
            ),

            const SizedBox(height: 20),

            // Data
            _secao('Data'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selecionarData,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 20, color: kOrange),
                    const SizedBox(width: 10),
                    Text(
                      _dataSelecionada != null
                          ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')}/${_dataSelecionada!.year}'
                          : 'Selecionar data',
                      style: TextStyle(
                        color: _dataSelecionada != null
                            ? Colors.black87
                            : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Horários
            _secao('Horário'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _campoHora(
                        'Início', _horaInicio, () => _selecionarHora(true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _campoHora(
                        'Fim', _horaFim, () => _selecionarHora(false))),
              ],
            ),

            const SizedBox(height: 16),

            // Vagas
            _secao('Número de vagas'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _vagasCtrl,
              keyboardType: TextInputType.number,
              decoration: _deco('Vagas disponíveis', Icons.people_outline),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe as vagas';
                final n = int.tryParse(v);
                if (n == null || n < 1) return 'Mínimo 1 vaga';
                return null;
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, color: Colors.white),
                label: const Text('Cadastrar disponibilidade',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Aba 2: Listagem ──────────────────────────────────────
  Widget _buildListagem() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_disponibilidades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nenhuma disponibilidade cadastrada',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _disponibilidades.length,
        itemBuilder: (ctx, i) {
          final d = _disponibilidades[i];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule, color: kOrange, size: 22),
              ),
              title: Text(
                _formatarData(d['data'].toString()),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${d['hora_inicio']} — ${d['hora_fim']}  •  ${d['vagas']} vaga(s)'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _remover((d['id'] as num).toInt()),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _secao(String titulo) => Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );

  Widget _campoHora(String label, TimeOfDay? hora, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: kOrange),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(
                  hora != null
                      ? '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}'
                      : 'Selecionar',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: hora != null ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: kOrange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kOrange),
        ),
      );

  String _formatarData(String data) {
    try {
      final partes = data.split('-');
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    } catch (_) {
      return data;
    }
  }
}
