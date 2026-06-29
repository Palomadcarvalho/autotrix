import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  // 10.0.2.2 é o IP do host no emulador Android
  // Em dispositivo físico, use o IP da sua máquina na rede local
  static const String _wsBase = 'ws://localhost:5000/ws';

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Timer? _pingTimer;
  bool _conectado = false;

  Stream<Map<String, dynamic>> get eventos => _controller.stream;
  bool get conectado => _conectado;

  void conectar(int clienteId) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsBase/$clienteId'),
      );
      _conectado = true;

      _channel!.stream.listen(
        (mensagem) {
          final dados = jsonDecode(mensagem as String) as Map<String, dynamic>;
          _controller.add(dados);
        },
        onError: (erro) {
          _conectado = false;
          _controller.addError(erro);
        },
        onDone: () {
          _conectado = false;
          Future.delayed(const Duration(seconds: 5), () {
            if (!_controller.isClosed) conectar(clienteId);
          });
        },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_conectado) _channel?.sink.add('ping');
      });
    } catch (e) {
      _conectado = false;
    }
  }

  void desconectar() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _conectado = false;
  }

  void dispose() {
    desconectar();
    _controller.close();
  }
}