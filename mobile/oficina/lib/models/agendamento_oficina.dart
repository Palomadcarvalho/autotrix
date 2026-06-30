class AgendamentoOficina {
  final int id;
  final int clienteId;
  final String clienteNome;
  final String clienteTelefone;
  final String placa;
  final String modelo;
  final String marca;
  final int ano;
  final String servicoNome;
  final double preco;
  final int duracaoMin;
  final DateTime dataHora;
  final DateTime? dataHoraSugerida;
  final String status;
  final String? observacoes;

  AgendamentoOficina({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.placa,
    required this.modelo,
    required this.marca,
    required this.ano,
    required this.servicoNome,
    required this.preco,
    required this.duracaoMin,
    required this.dataHora,
    this.dataHoraSugerida,
    required this.status,
    this.observacoes,
  });

  factory AgendamentoOficina.fromJson(Map<String, dynamic> json) {
    return AgendamentoOficina(
      id: (json['id'] as num).toInt(),
      clienteId: (json['cliente_id'] as num).toInt(),
      clienteNome: json['cliente_nome'] ?? '',
      clienteTelefone: json['cliente_telefone'] ?? '',
      placa: json['placa'] ?? '',
      modelo: json['modelo'] ?? '',
      marca: json['marca'] ?? '',
      ano: (json['ano'] as num).toInt(),
      servicoNome: json['servico_nome'] ?? '',
      preco: double.parse(json['preco'].toString()),
      duracaoMin: (json['duracao_min'] as num).toInt(),
      dataHora: _parseData(json['data_hora']),
      dataHoraSugerida: json['data_hora_sugerida'] != null
          ? _parseData(json['data_hora_sugerida'])
          : null,
      status: json['status'] ?? 'pendente',
      observacoes: json['observacoes'],
    );
  }

  static DateTime _parseData(dynamic valor) {
  if (valor == null) return DateTime.now();
  final s = valor.toString().trim();
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return DateTime.now();
  }
}

  bool get isPendente => status == 'pendente';
  bool get isConfirmado => status == 'confirmado';
  bool get isEmAndamento => status == 'em_andamento';
  bool get isConcluido => status == 'concluido';
  bool get isCancelado => status == 'cancelado';
  bool get isNegociacao => status == 'negociacao';

  String get veiculoDescricao => '$marca $modelo $ano — $placa';
}
