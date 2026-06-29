import 'package:flutter/material.dart';
import '../models/agendamento_oficina.dart';
import '../services/oficina_service.dart';
import '../widgets/widgets.dart';
import 'andamento_screen.dart';

class DetalhesScreen extends StatefulWidget {
  final AgendamentoOficina agendamento;
  const DetalhesScreen({super.key, required this.agendamento});

  @override
  State<DetalhesScreen> createState() => _DetalhesScreenState();
}

class _DetalhesScreenState extends State<DetalhesScreen> {
  final _service        = OficinaService();
  final _horarioCtrl    = TextEditingController();
  bool  _processando    = false;

  @override
  void dispose() {
    _horarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizar(String status, {String? sugerida}) async {
    setState(() => _processando = true);
    try {
      await _service.atualizarStatus(
        widget.agendamento.id,
        status,
        dataHoraSugerida: sugerida,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensagem(status)),
          backgroundColor: status == 'cancelado'
              ? Colors.red[700]
              : Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (status == 'confirmado' || status == 'em_andamento') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AndamentoScreen(
              agendamentoId: widget.agendamento.id,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarNegociacao() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sugerir outro horário',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'O cliente receberá a proposta e poderá aceitar ou recusar.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _horarioCtrl,
              decoration: InputDecoration(
                labelText: 'Novo horário (AAAA-MM-DDTHH:MM)',
                hintText:  '2026-05-20T14:00',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled:    true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final h = _horarioCtrl.text.trim();
                if (h.isEmpty) return;
                Navigator.pop(context);
                _atualizar('negociacao', sugerida: h);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Enviar proposta',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mensagem(String status) {
    switch (status) {
      case 'confirmado':  return 'Agendamento confirmado!';
      case 'cancelado':   return 'Agendamento recusado.';
      case 'negociacao':  return 'Proposta de horário enviada ao cliente.';
      default:            return 'Status atualizado.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agendamento;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes'),
        centerTitle: true,
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card principal
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
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        StatusBadge(status: a.status),
                      ],
                    ),
                    const Divider(height: 20),
                    _info('Cliente',    a.clienteNome),
                    _info('Telefone',   a.clienteTelefone),
                    _info('Serviço',    a.servicoNome),
                    _info('Veículo',    a.veiculoDescricao),
                    _info('Data/hora',  _fmt(a.dataHora)),
                    _info('Valor',
                        'R\$ ${a.preco.toStringAsFixed(2)}  •  ${a.duracaoMin} min'),
                    if (a.observacoes != null && a.observacoes!.isNotEmpty)
                      _info('Observações', a.observacoes!),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Ações — só para agendamentos pendentes
            if (a.isPendente) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processando
                          ? null
                          : () => _atualizar('cancelado'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Recusar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processando
                          ? null
                          : () => _atualizar('confirmado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _processando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Confirmar',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _processando ? null : _mostrarNegociacao,
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('Sugerir outro horário'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  side: BorderSide(color: Colors.orange[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            // Ação para confirmado — iniciar serviço
            if (a.isConfirmado)
              ElevatedButton.icon(
                onPressed: _processando
                    ? null
                    : () => _atualizar('em_andamento'),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text('Iniciar serviço',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}