class Servico {
  final int id;
  final String nome;
  final String? descricao;
  final int duracaoMin;
  final double preco;

  Servico({
    required this.id,
    required this.nome,
    this.descricao,
    required this.duracaoMin,
    required this.preco,
  });

  factory Servico.fromJson(Map<String, dynamic> json) {
    return Servico(
      id:         (json['id'] as num).toInt(),
      nome:       json['nome'],
      descricao:  json['descricao'],
      duracaoMin: (json['duracao_min'] as num).toInt(),
      preco:      double.parse(json['preco'].toString()),
    );
  }
}

class Disponibilidade {
  final int id;
  final String data;
  final String horaInicio;
  final String horaFim;
  final int vagas;

  Disponibilidade({
    required this.id,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.vagas,
  });

  factory Disponibilidade.fromJson(Map<String, dynamic> json) {
    return Disponibilidade(
      id:         (json['id'] as num).toInt(),
      data:       json['data'],
      horaInicio: json['hora_inicio'],
      horaFim:    json['hora_fim'],
      vagas:      (json['vagas'] as num).toInt(),
    );
  }
}

class Veiculo {
  final int id;
  final int clienteId;
  final String marca;
  final String modelo;
  final int ano;
  final String placa;

  Veiculo({
    required this.id,
    required this.clienteId,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.placa,
  });

  factory Veiculo.fromJson(Map<String, dynamic> json) {
    return Veiculo(
      id:        (json['id'] as num).toInt(),
      clienteId: (json['cliente_id'] as num).toInt(),
      marca:     json['marca'],
      modelo:    json['modelo'],
      ano:       (json['ano'] as num).toInt(),
      placa:     json['placa'],
    );
  }

  String get descricao => '$marca $modelo ($ano) — $placa';
}