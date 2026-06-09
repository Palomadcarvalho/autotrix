import 'package:flutter/material.dart';
import '../models/agendamento.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class DetalhesScreen extends StatefulWidget {
  final int agendamentoId;
  const DetalhesScreen({super.key, required this.agendamentoId});

  @override
  State<DetalhesScreen> createState() => _DetalhesScreenState();
}

class _DetalhesScreenState extends State<DetalhesScreen> {
  final _api = ApiService();
  Agendamento? _agendamento;
  bool _carregando = true;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final a = await _api.buscarAgendamento(widget.agendamentoId);
      if (mounted) setState(() { _agendamento = a; _carregando = false; });
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _responderNegociacao(String resposta) async {
    setState(() => _processando = true);
    try {
      await _api.responderNegociacao(widget.agendamentoId, resposta);
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resposta == 'confirmado'
                ? 'Horário aceito com sucesso!'
                : 'Agendamento cancelado.'),
            backgroundColor: resposta == 'confirmado'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar agendamento'),
        content: const Text('Deseja realmente cancelar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, cancelar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => _processando = true);
      try {
        await _api.cancelarAgendamento(widget.agendamentoId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do agendamento'),
        centerTitle: true,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _agendamento == null
              ? const Center(child: Text('Agendamento não encontrado'))
              : _buildDetalhes(),
    );
  }

  Widget _buildDetalhes() {
    final a = _agendamento!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      StatusBadge(status: a.status),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow(Icons.build, 'Serviço',
                      a.servicoNome ?? 'Serviço #${a.servicoId}'),
                  const SizedBox(height: 10),
                  _infoRow(Icons.directions_car, 'Veículo',
                      '${a.modelo ?? ''} — ${a.placa ?? ''}'),
                  const SizedBox(height: 10),
                  _infoRow(Icons.calendar_today, 'Data/hora',
                      _formatarData(a.dataHora)),
                  if (a.preco != null) ...[
                    const SizedBox(height: 10),
                    _infoRow(Icons.attach_money, 'Valor',
                        'R\$ ${a.preco!.toStringAsFixed(2)}'),
                  ],
                  if (a.observacoes != null &&
                      a.observacoes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _infoRow(Icons.notes, 'Observações', a.observacoes!),
                  ],
                ],
              ),
            ),
          ),

          // Card de negociação
          if (a.isNegociacao && a.dataHoraSugerida != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.purple, size: 18),
                      SizedBox(width: 8),
                      Text('A oficina propôs um novo horário',
                          style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Horário original:  ${_formatarData(a.dataHora)}',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Novo horário sugerido:  ${_formatarData(a.dataHoraSugerida!)}',
                    style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processando
                              ? null
                              : () => _responderNegociacao('cancelado'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                          child: const Text('Recusar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _processando
                              ? null
                              : () => _responderNegociacao('confirmado'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple),
                          child: _processando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Aceitar',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Botão cancelar (só se não estiver concluído/cancelado)
          if (!a.isConcluido && !a.isCancelado) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _processando ? null : _cancelar,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red)),
                child: const Text('Cancelar agendamento'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            Text(valor,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}