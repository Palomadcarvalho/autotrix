import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agendamento_oficina.dart';
import '../services/oficina_service.dart';
import '../widgets/widgets.dart';
import 'detalhes_screen.dart';
import 'login_screen.dart';
import 'disponibilidade_screen.dart';

class ListagemScreen extends StatefulWidget {
  const ListagemScreen({super.key});

  @override
  State<ListagemScreen> createState() => _ListagemScreenState();
}

class _ListagemScreenState extends State<ListagemScreen> {
  final _service = OficinaService();

  List<AgendamentoOficina> _pendentes = [];
  List<AgendamentoOficina> _emAndamento = [];
  bool _carregando = true;
  String _tabAtiva = 'pendente';
  Timer? _pollingTimer;
  int _totalAnterior = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _carregar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _carregando = true);
    try {
      final todos = await _service.listarAgendamentos(
        statusFiltro: ['pendente', 'confirmado', 'em_andamento'],
      );
      final pendentes = todos.where((a) => a.isPendente).toList();
      final emAndamento =
          todos.where((a) => a.isConfirmado || a.isEmAndamento).toList();

      if (silencioso && pendentes.length > _totalAnterior && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Novo agendamento recebido!'),
            backgroundColor: kOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _pendentes = pendentes;
          _emAndamento = emAndamento;
          _totalAnterior = pendentes.length;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _tabAtiva == 'pendente' ? _pendentes : _emAndamento;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitações'),
        centerTitle: true,
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        actions: [
          // Botão de disponibilidades
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Disponibilidades',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DisponibilidadeScreen()),
              );
              _carregar();
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            color: kOrange.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filtro('pendente', 'Pendentes (${_pendentes.length})'),
                const SizedBox(width: 8),
                _filtro('andamento', 'Em andamento (${_emAndamento.length})'),
              ],
            ),
          ),

          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 20),
                          itemCount: lista.length,
                          itemBuilder: (ctx, i) => AgendamentoCard(
                            agendamento: lista[i],
                            onTap: () async {
                              await Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => DetalhesScreen(
                                    agendamento: lista[i],
                                  ),
                                ),
                              );
                              _carregar();
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filtro(String valor, String label) {
    final ativo = _tabAtiva == valor;
    return GestureDetector(
      onTap: () => setState(() => _tabAtiva = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? kOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? kOrange : Colors.grey.withOpacity(0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ativo ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: ativo ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _tabAtiva == 'pendente'
                  ? 'Nenhuma solicitação pendente'
                  : 'Nenhum serviço em andamento',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Atualizando a cada 10 segundos',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
}
