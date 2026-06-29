import 'package:flutter/material.dart';
import '../models/agendamento.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../widgets/widgets.dart';
import 'detalhes_screen.dart';
import 'criar_screen.dart';
import 'login_screen.dart';

class ListagemScreen extends StatefulWidget {
  const ListagemScreen({super.key});

  @override
  State<ListagemScreen> createState() => _ListagemScreenState();
}

class _ListagemScreenState extends State<ListagemScreen> {
  final _api  = ApiService();
  final _auth = AuthService();
  final _ws   = WebSocketService();

  List<Agendamento> _agendamentos = [];
  Usuario?          _usuario;
  bool              _carregando = true;
  String?           _erro;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioEAgendamentos();
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarioEAgendamentos() async {
    final usuario = await _auth.getUsuarioLogado();
    if (!mounted) return;
    setState(() => _usuario = usuario);

    if (usuario != null) {
      _ws.conectar(usuario.id);
      _ws.eventos.listen((evento) {
        final tipo = evento['evento'] as String;
        if ([
          'agendamento.status.atualizado',
          'agendamento.negociacao.proposta',
          'agendamento.negociacao.respondida',
        ].contains(tipo)) {
          _carregarAgendamentos();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_mensagemEvento(tipo)),
                backgroundColor: Colors.indigo,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      });
    }

    await _carregarAgendamentos();
  }

  String _mensagemEvento(String tipo) {
    switch (tipo) {
      case 'agendamento.status.atualizado':
        return 'Seu agendamento foi atualizado!';
      case 'agendamento.negociacao.proposta':
        return 'A oficina propôs um novo horário. Toque para ver.';
      default:
        return 'Agendamento atualizado';
    }
  }

  Future<void> _carregarAgendamentos() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final lista = await _api.listarAgendamentos(
        clienteId: _usuario?.id,
      );
      if (mounted) {
        setState(() {
          _agendamentos = lista;
          _carregando   = false;
          _erro         = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.toString();
        });
      }
    }
  }

  void _mostrarMenuUsuario() {
    if (_usuario == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF1565C0),
              child: Text(
                _usuario!.iniciais,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            Text(_usuario!.nome,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text(_usuario!.email,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _auth.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Sair',
                    style: TextStyle(color: Colors.red, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus agendamentos'),
        centerTitle: true,
        actions: [
          if (_usuario != null)
            GestureDetector(
              onTap: _mostrarMenuUsuario,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1565C0),
                  child: Text(
                    _usuario!.iniciais,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
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
        icon: const Icon(Icons.add),
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
            Text('Nenhum agendamento ainda',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Toque no botão abaixo para agendar',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
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
                builder: (_) =>
                    DetalhesScreen(agendamentoId: _agendamentos[i].id),
              ),
            );
            _carregarAgendamentos();
          },
        ),
      ),
    );
  }
}