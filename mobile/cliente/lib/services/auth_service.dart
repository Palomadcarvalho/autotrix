import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:5000/api';
  static const String _chaveUsuario = 'usuario_logado';

  Future<Usuario> login(String email, String senha) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/clientes/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'senha': senha}),
    );

    if (res.statusCode == 200) {
      final usuario = Usuario.fromJson(jsonDecode(res.body));
      await _salvarUsuario(usuario);
      return usuario;
    } else if (res.statusCode == 401) {
      throw Exception('Credenciais inválidas');
    } else {
      throw Exception('Erro ao conectar com o servidor');
    }
  }

  Future<Usuario> cadastrar(
    String nome,
    String email,
    String telefone,
    String senha,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/clientes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome.trim(),
        'email': email.trim(),
        'telefone': telefone,
        'senha': senha,
      }),
    );

    if (res.statusCode == 201) {
      final usuario = Usuario.fromJson(jsonDecode(res.body));
      await _salvarUsuario(usuario);
      return usuario;
    } else if (res.statusCode == 400) {
      final erro = jsonDecode(res.body)['erro'] ?? 'Erro ao cadastrar';
      throw Exception(erro);
    } else {
      throw Exception('Erro ao conectar com o servidor');
    }
  }

  Future<void> _salvarUsuario(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUsuario, jsonEncode(usuario.toJson()));
  }

  Future<Usuario?> getUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_chaveUsuario);
    if (json == null) return null;
    return Usuario.fromJson(jsonDecode(json));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveUsuario);
  }
}
