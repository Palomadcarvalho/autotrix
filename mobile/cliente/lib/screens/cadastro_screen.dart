import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';
import 'veiculo_screen.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nomeCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _senhaCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth        = AuthService();

  bool _mostrarSenha    = false;
  bool _mostrarConfirm  = false;
  bool _carregando      = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      final usuario = await _auth.cadastrar(
        _nomeCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _telCtrl.text,
        _senhaCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VeiculoScreen(
            usuario: usuario,
            primeiroAcesso: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        centerTitle: true,
        elevation: 0,
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
                  _ponto(ativo: false),
                  const SizedBox(width: 6),
                  _ponto(ativo: false),
                ],
              ),

              const SizedBox(height: 28),

              // Campos
              _campo(_nomeCtrl, 'Nome completo', Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o nome' : null),

              const SizedBox(height: 14),

              _campo(_emailCtrl, 'E-mail', Icons.email_outlined,
                  tipo: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  }),

              const SizedBox(height: 14),

              _campo(_telCtrl, 'Telefone', Icons.phone_outlined,
                  tipo: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o telefone' : null),

              const SizedBox(height: 14),

              // Senha
              TextFormField(
                controller: _senhaCtrl,
                obscureText: !_mostrarSenha,
                decoration: _deco(
                  'Senha',
                  Icons.lock_outline,
                  sufixo: IconButton(
                    icon: Icon(
                      _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a senha';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Confirmar senha
              TextFormField(
                controller: _confirmCtrl,
                obscureText: !_mostrarConfirm,
                decoration: _deco(
                  'Confirmar senha',
                  Icons.lock_outline,
                  sufixo: IconButton(
                    icon: Icon(
                      _mostrarConfirm ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarConfirm = !_mostrarConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirme a senha';
                  if (v != _senhaCtrl.text) return 'As senhas não coincidem';
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // Botão continuar
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                ),
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
          color: ativo
              ? const Color(0xFF1565C0)
              : Colors.grey[300],
        ),
      );

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType tipo = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      decoration: _deco(label, icon),
      validator: validator,
    );
  }

  InputDecoration _deco(String label, IconData icon, {Widget? sufixo}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: sufixo,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}