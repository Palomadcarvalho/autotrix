import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class CriarScreen extends StatefulWidget {
  const CriarScreen({super.key});

  @override
  State<CriarScreen> createState() => _CriarScreenState();
}

class _CriarScreenState extends State<CriarScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _obsCtrl = TextEditingController();

  List<Servico> _servicos = [];
  List<Veiculo> _veiculos = [];
  List<Disponibilidade> _disponibilidades = [];

  Servico? _servicoSelecionado;
  Veiculo? _veiculoSelecionado;
  Disponibilidade? _horarioSelecionado;

  int _clienteId = 0;
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarClienteEDados();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarClienteEDados() async {
    final usuario = await _auth.getUsuarioLogado();
    if (usuario != null) {
      setState(() => _clienteId = usuario.id);
    }
    await _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (_clienteId == 0) {
      setState(() {
        _carregando = false;
        _erro = 'Usuário não autenticado';
      });
      return;
    }
    try {
      final resultados = await Future.wait([
        _api.listarServicos(),
        _api.listarVeiculos(_clienteId),
        _api.listarDisponibilidades(),
      ]);
      if (mounted) {
        setState(() {
          _servicos = resultados[0] as List<Servico>;
          _veiculos = resultados[1] as List<Veiculo>;
          _disponibilidades = resultados[2] as List<Disponibilidade>;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.toString();
        });
      }
    }
  }

  Future<void> _salvar() async {
    if (_servicoSelecionado == null ||
        _veiculoSelecionado == null ||
        _horarioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final dataHora =
          '${_horarioSelecionado!.data}T${_horarioSelecionado!.horaInicio}';

      await _api.criarAgendamento(
        clienteId: _clienteId,
        veiculoId: _veiculoSelecionado!.id,
        servicoId: _servicoSelecionado!.id,
        dataHora: dataHora,
        observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento criado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo agendamento'),
        centerTitle: true,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!))
              : _buildFormulario(),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secao('Serviço desejado'),
          const SizedBox(height: 8),
          ..._servicos.map((s) => _servicoTile(s)),
          const SizedBox(height: 24),
          _secao('Veículo'),
          const SizedBox(height: 8),
          if (_veiculos.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Nenhum veículo cadastrado',
                      style: TextStyle(color: Colors.orange)),
                ],
              ),
            )
          else
            ..._veiculos.map((v) => _veiculoTile(v)),
          const SizedBox(height: 24),
          _secao('Horário disponível'),
          const SizedBox(height: 8),
          if (_disponibilidades.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'Nenhum horário disponível no momento',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._disponibilidades.map((d) => _horarioTile(d)),
          const SizedBox(height: 24),
          _secao('Observações (opcional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _obsCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex.: veículo apresenta barulho no motor',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _salvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirmar agendamento',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _secao(String titulo) => Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _servicoTile(Servico s) {
    final sel = _servicoSelecionado?.id == s.id;
    return GestureDetector(
      onTap: () => setState(() => _servicoSelecionado = s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
            width: sel ? 2 : 1,
          ),
          color: sel
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nome,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (s.descricao != null && s.descricao!.isNotEmpty)
                    Text(s.descricao!,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  Text(
                      '${s.duracaoMin} min  •  R\$ ${s.preco.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            if (sel)
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _veiculoTile(Veiculo v) {
    final sel = _veiculoSelecionado?.id == v.id;
    return GestureDetector(
      onTap: () => setState(() => _veiculoSelecionado = v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
            width: sel ? 2 : 1,
          ),
          color: sel
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(v.descricao,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (sel)
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _horarioTile(Disponibilidade d) {
    final sel = _horarioSelecionado?.id == d.id;
    return GestureDetector(
      onTap: () => setState(() => _horarioSelecionado = d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? Colors.green : Colors.grey.withOpacity(0.3),
            width: sel ? 2 : 1,
          ),
          color: sel ? Colors.green.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: Colors.green),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.data,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('${d.horaInicio} — ${d.horaFim}  •  ${d.vagas} vaga(s)',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const Spacer(),
            if (sel) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
