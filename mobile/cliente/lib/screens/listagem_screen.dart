import 'package:flutter/material.dart';
import '../models/agendamento.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/widgets.dart';
import 'detalhes_screen.dart';
import 'criar_screen.dart';

class ListagemScreen extends StatefulWidget {
  // ID fixo para desenvolvimento — na Sprint 4 vira login real
  static const int clienteIdDemo = 1;

  const ListagemScreen({super.key});

  @override
  State<ListagemScreen> createState() => _ListagemScreenState();
}

class _ListagemScreenState extends State<ListagemScreen> {
  final _api = ApiService();
  final _ws  = WebSocketService();

  List<Agendamento> _agendamentos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarAgendamentos();
    _iniciarWebSocket();
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }

  void _iniciarWebSocket() {
    _ws.conectar(ListagemScreen.clienteIdDemo);

    // Escuta eventos em tempo real e recarrega quando necessário
    _ws.eventos.listen((evento) {
      final tipo = evento['evento'] as String;
      if ([
        'agendamento.status.atualizado',
        'agendamento.negociacao.proposta',
        'agendamento.negociacao.respondida',
      ].contains(tipo)) {
        _carregarAgendamentos();

        // Mostra snackbar informando a atualização
        if (mounted) {
          final mensagem = _mensagemEvento(tipo, evento['dados']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensagem),
              backgroundColor: Colors.indigo,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  String _mensagemEvento(String tipo, Map<String, dynamic>? dados) {
    switch (tipo) {
      case 'agendamento.status.atualizado':
        final novo = dados?['status_novo'] ?? '';
        return 'Agendamento atualizado: $novo';
      case 'agendamento.negociacao.proposta':
        return 'A oficina propôs um novo horário! Toque para ver.';
      default:
        return 'Agendamento atualizado';
    }
  }

  Future<void> _carregarAgendamentos() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final lista = await _api.listarAgendamentos(
        clienteId: ListagemScreen.clienteIdDemo,
      );
      if (mounted) {
        setState(() {
          _agendamentos = lista;
          _carregando   = false;
          _erro         = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _carregando = false; _erro = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus agendamentos'),
        centerTitle: true,
        actions: [
          // Indicador de conexão WebSocket
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.circle,
              size: 10,
              color: _ws.conectado ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarScreen()),
          );
          _carregarAgendamentos();
        },
        icon:  const Icon(Icons.add),
        label: const Text('Novo agendamento'),
      ),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarAgendamentos,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_agendamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Nenhum agendamento ainda',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no botão abaixo para agendar',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarAgendamentos,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _agendamentos.length,
        itemBuilder: (ctx, i) => AgendamentoCard(
          agendamento: _agendamentos[i],
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => DetalhesScreen(
                  agendamentoId: _agendamentos[i].id,
                ),
              ),
            );
            _carregarAgendamentos();
          },
        ),
      ),
    );
  }
}