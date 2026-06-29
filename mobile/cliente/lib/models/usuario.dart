import 'dart:convert';

class Usuario {
  final int id;
  final String nome;
  final String email;
  final String telefone;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.telefone,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id:       (json['id'] as num).toInt(),
      nome:     json['nome'] as String,
      email:    json['email'] as String,
      telefone: json['telefone'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':       id,
    'nome':     nome,
    'email':    email,
    'telefone': telefone,
  };

  String get iniciais {
    final partes = nome.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }
}