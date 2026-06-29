import json
import logging
from flask_sock import Sock
from simple_websocket import ConnectionClosed

logger = logging.getLogger(__name__)

sock = Sock()

_conexoes: dict[str, list] = {}


def init_websocket(app):
    sock.init_app(app)


def registrar_conexao(cliente_id: str, ws):
    if cliente_id not in _conexoes:
        _conexoes[cliente_id] = []
    _conexoes[cliente_id].append(ws)
    logger.info(f"[WS] Cliente {cliente_id} conectado — {len(_conexoes[cliente_id])} conexão(ões) ativa(s)")


def remover_conexao(cliente_id: str, ws):
    if cliente_id in _conexoes:
        try:
            _conexoes[cliente_id].remove(ws)
        except ValueError:
            pass
        if not _conexoes[cliente_id]:
            del _conexoes[cliente_id]
    logger.info(f"[WS] Cliente {cliente_id} desconectado")


def notificar_cliente(cliente_id: int | str, evento: str, dados: dict):
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


def registrar_rotas(app):

    @sock.route("/ws/<cliente_id>")
    def websocket_cliente(ws, cliente_id):
        registrar_conexao(cliente_id, ws)
        try:
            ws.send(json.dumps({
                "evento": "conexao_estabelecida",
                "dados":  {"cliente_id": cliente_id, "mensagem": "Conectado ao Autotrix"}
            }))

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