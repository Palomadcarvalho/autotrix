import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agendamento_oficina.dart';

class OficinaService {
  static const String _baseUrl = 'http://localhost:5000/api';
  static const String _chaveAuth = 'oficina_logada';

  Future<Map<String, dynamic>> login(String email, String senha) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/oficina/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'senha': senha}),
    );

    if (res.statusCode == 200) {
      final dados = jsonDecode(res.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveAuth, jsonEncode(dados));
      return dados;
    } else if (res.statusCode == 401) {
      throw Exception('Credenciais inválidas');
    } else {
      throw Exception('Erro ao conectar com o servidor');
    }
  }

  Future<Map<String, dynamic>?> getOficinaLogada() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_chaveAuth);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveAuth);
  }

  Future<List<AgendamentoOficina>> listarAgendamentos({
    List<String>? statusFiltro,
  }) async {
    String url = '$_baseUrl/oficina/agendamentos';
    if (statusFiltro != null && statusFiltro.isNotEmpty) {
      url += '?status=${statusFiltro.join(",")}';
    }

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => AgendamentoOficina.fromJson(j)).toList();
    }
    throw Exception('Erro ao carregar agendamentos');
  }

  Future<void> atualizarStatus(
    int agendamentoId,
    String novoStatus, {
    String? dataHoraSugerida,
  }) async {
    final body = <String, dynamic>{'status': novoStatus};
    if (dataHoraSugerida != null) {
      body['data_hora_sugerida'] = dataHoraSugerida;
    }

    final res = await http.patch(
      Uri.parse('$_baseUrl/oficina/agendamentos/$agendamentoId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final erro = jsonDecode(res.body)['erro'] ?? 'Erro ao atualizar status';
      throw Exception(erro);
    }
  }
}
