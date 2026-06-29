import 'package:flutter/material.dart';
import '../models/agendamento_oficina.dart';

const Color kOrange = Color(0xFFE65100);

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:        cfg.cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: cfg.cor.withOpacity(0.4)),
      ),
      child: Text(
        cfg.label,
        style: TextStyle(
          color:      cfg.cor,
          fontSize:   11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _Cfg _config(String s) {
    switch (s) {
      case 'pendente':     return _Cfg('Pendente',      Colors.orange[700]!);
      case 'negociacao':   return _Cfg('Negociação',    Colors.purple);
      case 'confirmado':   return _Cfg('Confirmado',    Colors.blue[700]!);
      case 'em_andamento': return _Cfg('Em andamento',  kOrange);
      case 'concluido':    return _Cfg('Concluído',     Colors.green[700]!);
      case 'cancelado':    return _Cfg('Cancelado',     Colors.red[700]!);
      default:             return _Cfg(s,               Colors.grey);
    }
  }
}

class _Cfg {
  final String label;
  final Color  cor;
  _Cfg(this.label, this.cor);
}

class AgendamentoCard extends StatelessWidget {
  final AgendamentoOficina agendamento;
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
      margin:    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    a.clienteNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  StatusBadge(status: a.status),
                ],
              ),
              const SizedBox(height: 6),
              _linha(Icons.build_outlined, a.servicoNome),
              const SizedBox(height: 3),
              _linha(Icons.directions_car_outlined, a.veiculoDescricao),
              const SizedBox(height: 3),
              _linha(Icons.calendar_today_outlined, _fmt(a.dataHora)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linha(IconData icon, String txt) => Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              txt,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}