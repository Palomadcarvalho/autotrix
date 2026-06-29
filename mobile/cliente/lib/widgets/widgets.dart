import 'package:flutter/material.dart';
import '../models/agendamento.dart';


class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        config.cor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: config.cor.withOpacity(0.4)),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color:      config.cor,
          fontSize:   12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'pendente':
        return _StatusConfig('Pendente', Colors.orange);
      case 'negociacao':
        return _StatusConfig('Negociação', Colors.purple);
      case 'confirmado':
        return _StatusConfig('Confirmado', Colors.blue);
      case 'em_andamento':
        return _StatusConfig('Em andamento', Colors.indigo);
      case 'concluido':
        return _StatusConfig('Concluído', Colors.green);
      case 'cancelado':
        return _StatusConfig('Cancelado', Colors.red);
      default:
        return _StatusConfig(status, Colors.grey);
    }
  }
}

class _StatusConfig {
  final String label;
  final Color cor;
  _StatusConfig(this.label, this.cor);
}

// ── AgendamentoCard ───────────────────────────────────────────

class AgendamentoCard extends StatelessWidget {
  final Agendamento agendamento;
  final VoidCallback onTap;

  const AgendamentoCard({
    super.key,
    required this.agendamento,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    return Card(
      margin:      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation:   0,
      shape:       RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap:       onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      a.servicoNome ?? 'Serviço #${a.servicoId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StatusBadge(status: a.status),
                ],
              ),
              const SizedBox(height: 8),
              if (a.placa != null)
                Row(
                  children: [
                    Icon(Icons.directions_car,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${a.modelo} — ${a.placa}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatarData(a.dataHora),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              if (a.isNegociacao && a.dataHoraSugerida != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'Novo horário sugerido: ${_formatarData(a.dataHoraSugerida!)}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}