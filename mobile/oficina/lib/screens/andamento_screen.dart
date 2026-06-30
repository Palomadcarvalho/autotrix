import 'package:flutter/material.dart';
import '../services/oficina_service.dart';
import '../models/agendamento_oficina.dart';
import '../widgets/widgets.dart';

class AndamentoScreen extends StatefulWidget {
  final int agendamentoId;
  const AndamentoScreen({super.key, required this.agendamentoId});

  @override
  State<AndamentoScreen> createState() => _AndamentoScreenState();
}

class _AndamentoScreenState extends State<AndamentoScreen> {
  final _service = OficinaService();

  AgendamentoOficina? _agendamento;
  bool _carregando  = true;
  bool _concluindo  = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
  try {
    final todos = await _service.listarAgendamentos(
      statusFiltro: ['pendente', 'confirmado', 'em_andamento', 'concluido', 'cancelado'],
    );
    final ag = todos.where((a) => a.id == widget.agendamentoId).firstOrNull;
    if (mounted) setState(() { _agendamento = ag; _carregando = false; });
  } catch (_) {
    if (mounted) setState(() => _carregando = false);
  }
}

  Future<void> _concluir() async {
    setState(() => _concluindo = true);
    try {
      await _service.atualizarStatus(widget.agendamentoId, 'concluido');
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço concluído! Cliente foi notificado.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _concluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acompanhamento'),
        centerTitle: true,
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _agendamento == null
              ? const Center(child: Text('Agendamento não encontrado'))
              : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    final a = _agendamento!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Card do agendamento
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Agendamento #${a.id}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      StatusBadge(status: a.status),
                    ],
                  ),
                  const Divider(height: 20),
                  _info('Cliente',  a.clienteNome),
                  _info('Serviço',  a.servicoNome),
                  _info('Veículo',  a.veiculoDescricao),
                  _info('Data/hora', _fmt(a.dataHora)),
                  _info('Valor',
                      'R\$ ${a.preco.toStringAsFixed(2)}  •  ${a.duracaoMin} min'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Progresso visual do status
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Progresso do serviço',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 16),
                  _passo(
                    label:   'Confirmado',
                    ativo:   true,
                    cor:     Colors.green,
                  ),
                  _linha_progresso(ativo: a.isEmAndamento || a.isConcluido),
                  _passo(
                    label:   'Em andamento',
                    ativo:   a.isEmAndamento || a.isConcluido,
                    cor:     kOrange,
                  ),
                  _linha_progresso(ativo: a.isConcluido),
                  _passo(
                    label:   'Concluído',
                    ativo:   a.isConcluido,
                    cor:     Colors.green[700]!,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botão concluir
          if (!a.isConcluido)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _concluindo ? null : _concluir,
                icon: _concluindo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                label: const Text('Marcar como concluído',
                    style:
                        TextStyle(fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (a.isConcluido) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Serviço concluído! O cliente foi notificado.',
                      style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar para solicitações'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _passo({
    required String label,
    required bool ativo,
    required Color cor,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ativo ? cor : Colors.grey[200],
          ),
          child: ativo
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: ativo ? FontWeight.w600 : FontWeight.normal,
            color: ativo ? cor : Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _linha_progresso({required bool ativo}) => Padding(
        padding: const EdgeInsets.only(left: 11, top: 3, bottom: 3),
        child: Container(
          width: 2,
          height: 18,
          color: ativo ? Colors.green : Colors.grey[200],
        ),
      );

  Widget _info(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text(valor,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}