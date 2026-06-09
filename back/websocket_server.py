"""
websocket_server.py
─────────────────────────────────────────────────────────────────
Servidor WebSocket do Autotrix usando Flask-Sock.

Fluxo:
  1. App Flutter conecta em ws://localhost:5000/ws/<cliente_id>
  2. Consumer RabbitMQ detecta evento relevante para aquele cliente
  3. Backend envia a mensagem pelo WebSocket aberto
  4. App Flutter atualiza a UI em tempo real — sem polling

Gerenciamento de conexões:
  - Dicionário global {cliente_id: [lista de sockets ativos]}
  - Suporta múltiplas conexões por cliente (tablet + celular)
  - Remove automaticamente sockets mortos ao detectar desconexão
─────────────────────────────────────────────────────────────────
"""

import json
import logging
from flask_sock import Sock
from simple_websocket import ConnectionClosed

logger = logging.getLogger(__name__)

sock = Sock()

# Registro global de conexões WebSocket ativas
# { cliente_id (str): [ws1, ws2, ...] }
_conexoes: dict[str, list] = {}


def init_websocket(app):
    """Registra o servidor WebSocket na instância Flask."""
    sock.init_app(app)


def registrar_conexao(cliente_id: str, ws):
    """Adiciona um socket à lista do cliente."""
    if cliente_id not in _conexoes:
        _conexoes[cliente_id] = []
    _conexoes[cliente_id].append(ws)
    logger.info(f"[WS] Cliente {cliente_id} conectado — {len(_conexoes[cliente_id])} conexão(ões) ativa(s)")


def remover_conexao(cliente_id: str, ws):
    """Remove um socket da lista ao detectar desconexão."""
    if cliente_id in _conexoes:
        try:
            _conexoes[cliente_id].remove(ws)
        except ValueError:
            pass
        if not _conexoes[cliente_id]:
            del _conexoes[cliente_id]
    logger.info(f"[WS] Cliente {cliente_id} desconectado")


def notificar_cliente(cliente_id: int | str, evento: str, dados: dict):
    """
    Envia um evento em tempo real para todos os sockets
    ativos de um cliente específico.

    Chamado pelo consumer RabbitMQ após processar uma mensagem.
    """
    cid = str(cliente_id)
    if cid not in _conexoes or not _conexoes[cid]:
        logger.info(f"[WS] Cliente {cid} sem conexão ativa — evento '{evento}' não entregue em tempo real")
        return

    payload = json.dumps({
        "evento": evento,
        "dados":  dados,
    }, default=str)

    mortos = []
    for ws in _conexoes[cid]:
        try:
            ws.send(payload)
            logger.info(f"[WS] Evento '{evento}' enviado ao cliente {cid}")
        except (ConnectionClosed, Exception) as exc:
            logger.warning(f"[WS] Socket morto detectado para cliente {cid}: {exc}")
            mortos.append(ws)

    for ws in mortos:
        remover_conexao(cid, ws)


# ── Rota WebSocket ────────────────────────────────────────────
def registrar_rotas(app):
    """
    Registra a rota WebSocket no app Flask.
    Separado para evitar import circular com app.py.
    """

    @sock.route("/ws/<cliente_id>")
    def websocket_cliente(ws, cliente_id):
        """
        ws://localhost:5000/ws/<cliente_id>

        O app Flutter do cliente conecta nesta rota ao iniciar.
        A conexão fica aberta aguardando eventos do servidor.
        """
        registrar_conexao(cliente_id, ws)
        try:
            # Envia confirmação de conexão
            ws.send(json.dumps({
                "evento": "conexao_estabelecida",
                "dados":  {"cliente_id": cliente_id, "mensagem": "Conectado ao Autotrix"}
            }))

            # Mantém a conexão viva aguardando mensagens do cliente
            # (o cliente pode enviar "ping" para manter o socket aberto)
            while True:
                msg = ws.receive(timeout=30)
                if msg is None:
                    break
                if msg == "ping":
                    ws.send(json.dumps({"evento": "pong"}))

        except ConnectionClosed:
            pass
        finally:
            remover_conexao(cliente_id, ws)