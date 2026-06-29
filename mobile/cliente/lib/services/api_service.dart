import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agendamento.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';


  Future<List<Servico>> listarServicos() async {
    final res = await http.get(Uri.parse('$baseUrl/servicos/'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => Servico.fromJson(j)).toList();
    }
    throw Exception('Erro ao carregar serviços: ${res.statusCode}');
  }


  Future<List<Disponibilidade>> listarDisponibilidades({String? data}) async {
    final uri = data != null
        ? Uri.parse('$baseUrl/disponibilidades/?data=$data')
        : Uri.parse('$baseUrl/disponibilidades/');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List json = jsonDecode(res.body);
      return json.map((j) => Disponibilidade.fromJson(j)).toList();
    }
    throw Exception('Erro ao carregar disponibilidades: ${res.statusCode}');
  }


  Future<List<Veiculo>> listarVeiculos(int clienteId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/veiculos/?cliente_id=$clienteId'),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => Veiculo.fromJson(j)).toList();
    }
    throw Exception('Erro ao carregar veículos: ${res.statusCode}');
  }

  Future<List<Agendamento>> listarAgendamentos({int? clienteId}) async {
    final uri = clienteId != null
        ? Uri.parse('$baseUrl/agendamentos/?cliente_id=$clienteId')
        : Uri.parse('$baseUrl/agendamentos/');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => Agendamento.fromJson(j)).toList();
    }
    throw Exception('Erro ao carregar agendamentos: ${res.statusCode}');
  }

  Future<Agendamento> buscarAgendamento(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/agendamentos/$id'));
    if (res.statusCode == 200) {
      return Agendamento.fromJson(jsonDecode(res.body));
    }
    throw Exception('Agendamento não encontrado');
  }

  Future<Agendamento> criarAgendamento({
    required int clienteId,
    required int veiculoId,
    required int servicoId,
    required String dataHora,
    String? observacoes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/agendamentos/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cliente_id': clienteId,
        'veiculo_id': veiculoId,
        'servico_id': servicoId,
        'data_hora': dataHora,
        if (observacoes != null) 'observacoes': observacoes,
      }),
    );
    if (res.statusCode == 201) {
      return Agendamento.fromJson(jsonDecode(res.body));
    }
    throw Exception(
        'Erro ao criar agendamento: ${jsonDecode(res.body)['erro']}');
  }

  Future<void> responderNegociacao(int id, String resposta) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/agendamentos/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': resposta}),
    );
    if (res.statusCode != 200) {
      throw Exception('Erro ao responder negociação');
    }
  }

  Future<void> cancelarAgendamento(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/agendamentos/$id'),
    );
    if (res.statusCode != 200) {
      throw Exception('Erro ao cancelar agendamento');
    }
  }
}
