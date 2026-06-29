import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import 'listagem_screen.dart';

class VeiculoScreen extends StatefulWidget {
  final Usuario usuario;
  final bool primeiroAcesso;

  const VeiculoScreen({
    super.key,
    required this.usuario,
    required this.primeiroAcesso,
  });

  @override
  State<VeiculoScreen> createState() => _VeiculoScreenState();
}

class _VeiculoScreenState extends State<VeiculoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modeloCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  static const List<String> _marcas = [
    'Chevrolet',
    'Fiat',
    'Volkswagen',
    'Toyota',
    'Honda',
    'Hyundai',
    'Ford',
    'Renault',
    'Jeep',
    'Nissan',
    'Outro',
  ];

  String? _marcaSelecionada;
  bool _salvando = false;

  @override
  void dispose() {
    _modeloCtrl.dispose();
    _anoCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrarVeiculo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/api/veiculos/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id': widget.usuario.id,
          'marca': _marcaSelecionada,
          'modelo': _modeloCtrl.text.trim(),
          'ano': int.parse(_anoCtrl.text.trim()),
          'placa': _placaCtrl.text.trim().toUpperCase(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        _irParaListagem();
      } else {
        final erro =
            jsonDecode(res.body)['erro'] ?? 'Erro ao cadastrar veículo';
        final msg = erro.toString().toLowerCase().contains('unique')
            ? 'Placa já cadastrada'
            : erro.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _irParaListagem() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ListagemScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu veículo'),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: !widget.primeiroAcesso,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de passos
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ponto(ativo: true),
                  const SizedBox(width: 6),
                  _ponto(ativo: true),
                  const SizedBox(width: 6),
                  _ponto(ativo: false),
                ],
              ),

              const SizedBox(height: 16),

              // Banner de sucesso (só no primeiro acesso)
              if (widget.primeiroAcesso)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.green[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conta criada! Agora cadastre seu veículo.',
                          style:
                              TextStyle(color: Colors.green[800], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Dropdown marca
              DropdownButtonFormField<String>(
                value: _marcaSelecionada,
                decoration: _deco('Marca', Icons.directions_car_outlined),
                items: _marcas
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _marcaSelecionada = v),
                validator: (v) => v == null ? 'Selecione a marca' : null,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _modeloCtrl,
                decoration: _deco('Modelo', Icons.directions_car_outlined),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o modelo' : null,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _anoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Ano', Icons.calendar_today_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe o ano';
                        final ano = int.tryParse(v);
                        if (ano == null) return 'Ano inválido';
                        final anoAtual = DateTime.now().year;
                        if (ano < 1990 || ano > anoAtual) {
                          return '1990–$anoAtual';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _placaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _deco('Placa', Icons.pin_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe a placa';
                        if (v.length < 7) return 'Placa inválida';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _cadastrarVeiculo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Cadastrar veículo',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _irParaListagem,
                child: const Text('Pular por agora'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ponto({required bool ativo}) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ativo ? const Color(0xFF1565C0) : Colors.grey[300],
        ),
      );

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
