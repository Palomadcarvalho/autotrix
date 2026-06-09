import 'dart:io' show HttpDate;

DateTime _parseDate(String s) {
  try {
    return DateTime.parse(s);
  } catch (_) {
    return HttpDate.parse(s);
  }
}

class Agendamento {
  final int id;
  final int clienteId;
  final int veiculoId;
  final int servicoId;
  final DateTime dataHora;
  final DateTime? dataHoraSugerida;
  final String status;
  final String? observacoes;
  final String? clienteNome;
  final String? placa;
  final String? modelo;
  final String? servicoNome;
  final double? preco;

  Agendamento({
    required this.id,
    required this.clienteId,
    required this.veiculoId,
    required this.servicoId,
    required this.dataHora,
    this.dataHoraSugerida,
    required this.status,
    this.observacoes,
    this.clienteNome,
    this.placa,
    this.modelo,
    this.servicoNome,
    this.preco,
  });

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      id:                (json['id'] as num).toInt(),
      clienteId:         (json['cliente_id'] as num).toInt(),
      veiculoId:         (json['veiculo_id'] as num).toInt(),
      servicoId:         (json['servico_id'] as num).toInt(),
      dataHora:          _parseDate(json['data_hora']),
      dataHoraSugerida:  json['data_hora_sugerida'] != null
                            ? _parseDate(json['data_hora_sugerida'])
                            : null,
      status:            json['status'],
      observacoes:       json['observacoes'],
      clienteNome:       json['cliente_nome'],
      placa:             json['placa'],
      modelo:            json['modelo'],
      servicoNome:       json['servico_nome'],
      preco:             json['preco'] != null
                            ? (json['preco'] as num).toDouble()
                            : null,
    );
  }

  bool get isPendente     => status == 'pendente';
  bool get isNegociacao   => status == 'negociacao';
  bool get isConfirmado   => status == 'confirmado';
  bool get isEmAndamento  => status == 'em_andamento';
  bool get isConcluido    => status == 'concluido';
  bool get isCancelado    => status == 'cancelado';
}