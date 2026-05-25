"""
mom/consumer.py
─────────────────────────────────────────────────────────────────
Consumer de eventos do Autotrix — Sprint 2.

Responsabilidades:
  1. Conectar ao RabbitMQ e declarar exchange + filas
  2. Processar cada mensagem recebida
  3. Logar no terminal (evidência visual imediata)
  4. Persistir no PostgreSQL — tabela eventos_log (histórico auditável)

Fluxo de cada mensagem:
  RabbitMQ → consumer → handler específico → log + banco → ACK

Para rodar manualmente (fora do Docker):
  python -m mom.consumer

No Docker Compose (Sprint 2), este módulo sobe como serviço separado:
  docker compose up consumer
─────────────────────────────────────────────────────────────────
"""

import os
import json
import logging
import psycopg2
import psycopg2.extras
import pika
from datetime import datetime, timezone
from dotenv import load_dotenv

load_dotenv()

# ── Logging estruturado ───────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ── Constantes ────────────────────────────────────────────────
EXCHANGE_NAME = "autotrix.events"

FILAS = [
    {
        "nome":        "q.agendamento.criado",
        "routing_key": "agendamento.criado",
        "descricao":   "Novo agendamento criado pelo cliente → notifica OFICINA",
    },
    {
        "nome":        "q.agendamento.status",
        "routing_key": "agendamento.status.atualizado",
        "descricao":   "Status do agendamento alterado → notifica CLIENTE",
    },
    {
        "nome":        "q.negociacao.proposta",
        "routing_key": "agendamento.negociacao.proposta",
        "descricao":   "Oficina propõe horário alternativo → notifica CLIENTE",
    },
    {
        "nome":        "q.negociacao.respondida",
        "routing_key": "agendamento.negociacao.respondida",
        "descricao":   "Cliente respondeu à negociação → notifica OFICINA",
    },
]


# ── Conexão com PostgreSQL ────────────────────────────────────
def get_pg_connection():
    return psycopg2.connect(
        os.environ["DATABASE_URL"],
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def salvar_evento_no_banco(envelope: dict, fila: str):
    """
    Persiste o evento processado na tabela eventos_log.
    Garante rastreabilidade completa de todos os eventos consumidos.
    """
    dados = envelope.get("dados", {})
    try:
        conn = get_pg_connection()
        cur  = conn.cursor()
        cur.execute("""
            INSERT INTO eventos_log
                (evento, fila, agendamento_id, cliente_id, payload)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            envelope.get("evento"),
            fila,
            dados.get("agendamento_id"),
            dados.get("cliente_id"),
            json.dumps(envelope),
        ))
        conn.commit()
        cur.close()
        conn.close()
        logger.info(f"[DB] Evento persistido em eventos_log — fila: {fila}")
    except Exception as exc:
        logger.error(f"[DB] Falha ao persistir evento: {exc}")


# ── Declaração do exchange e filas ────────────────────────────
def declarar_infraestrutura(channel):
    """
    Declara exchange, filas e bindings.
    Operação idempotente — seguro chamar toda vez que o consumer inicia.
    """
    channel.exchange_declare(
        exchange=EXCHANGE_NAME,
        exchange_type="topic",
        durable=True,
    )
    for fila in FILAS:
        channel.queue_declare(queue=fila["nome"], durable=True)
        channel.queue_bind(
            exchange=EXCHANGE_NAME,
            queue=fila["nome"],
            routing_key=fila["routing_key"],
        )
        logger.info(
            f"[MOM] Fila declarada: '{fila['nome']}' "
            f"→ routing_key: '{fila['routing_key']}'"
        )


# ── Handlers específicos por evento ──────────────────────────

def handle_agendamento_criado(channel, method, properties, body):
    """
    Evento: agendamento.criado
    Consumidor: App da OFICINA
    Ação: notificar a oficina de que há uma nova demanda pendente.

    Na Sprint 3/4 este handler vai chamar a API de notificações
    push (Firebase Cloud Messaging) para exibir um alerta no
    app da oficina em tempo real.
    """
    envelope = json.loads(body)
    dados    = envelope.get("dados", {})

    # ── Log detalhado no terminal ─────────────────────────────
    logger.info("=" * 60)
    logger.info("[EVENTO] agendamento.criado")
    logger.info(f"  → Agendamento ID : {dados.get('agendamento_id')}")
    logger.info(f"  → Cliente ID     : {dados.get('cliente_id')}")
    logger.info(f"  → Veículo ID     : {dados.get('veiculo_id')}")
    logger.info(f"  → Serviço ID     : {dados.get('servico_id')}")
    logger.info(f"  → Data/Hora      : {dados.get('data_hora')}")
    logger.info(f"  → Observações    : {dados.get('observacoes')}")
    logger.info(f"  → Timestamp MOM  : {envelope.get('timestamp')}")
    logger.info("[AÇÃO] Notificando app da OFICINA sobre nova demanda...")
    logger.info("=" * 60)

    # ── Persistência no banco ─────────────────────────────────
    salvar_evento_no_banco(envelope, method.routing_key)

    # ── ACK: confirma ao broker que a mensagem foi processada ─
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_status_atualizado(channel, method, properties, body):
    """
    Evento: agendamento.status.atualizado
    Consumidor: App do CLIENTE
    Ação: notificar o cliente de que o status do seu agendamento mudou.
    """
    envelope = json.loads(body)
    dados    = envelope.get("dados", {})

    logger.info("=" * 60)
    logger.info("[EVENTO] agendamento.status.atualizado")
    logger.info(f"  → Agendamento ID : {dados.get('agendamento_id')}")
    logger.info(f"  → Cliente ID     : {dados.get('cliente_id')}")
    logger.info(f"  → Status anterior: {dados.get('status_anterior')}")
    logger.info(f"  → Status novo    : {dados.get('status_novo')}")
    logger.info(f"  → Timestamp MOM  : {envelope.get('timestamp')}")
    logger.info("[AÇÃO] Notificando app do CLIENTE sobre mudança de status...")
    logger.info("=" * 60)

    salvar_evento_no_banco(envelope, method.routing_key)
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_negociacao_proposta(channel, method, properties, body):
    """
    Evento: agendamento.negociacao.proposta
    Consumidor: App do CLIENTE
    Ação: exibir a proposta de horário alternativo da oficina para o cliente.
    """
    envelope = json.loads(body)
    dados    = envelope.get("dados", {})

    logger.info("=" * 60)
    logger.info("[EVENTO] agendamento.negociacao.proposta")
    logger.info(f"  → Agendamento ID    : {dados.get('agendamento_id')}")
    logger.info(f"  → Cliente ID        : {dados.get('cliente_id')}")
    logger.info(f"  → Horário original  : {dados.get('data_hora_original')}")
    logger.info(f"  → Horário sugerido  : {dados.get('data_hora_sugerida')}")
    logger.info(f"  → Timestamp MOM     : {envelope.get('timestamp')}")
    logger.info("[AÇÃO] Notificando app do CLIENTE sobre proposta de negociação...")
    logger.info("=" * 60)

    salvar_evento_no_banco(envelope, method.routing_key)
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_negociacao_respondida(channel, method, properties, body):
    """
    Evento: agendamento.negociacao.respondida
    Consumidor: App da OFICINA
    Ação: informar à oficina se o cliente aceitou ou recusou a proposta.
    """
    envelope = json.loads(body)
    dados    = envelope.get("dados", {})

    resposta = dados.get("resposta", "desconhecida")
    emoji    = "✅" if resposta == "aceito" else "❌"

    logger.info("=" * 60)
    logger.info("[EVENTO] agendamento.negociacao.respondida")
    logger.info(f"  → Agendamento ID : {dados.get('agendamento_id')}")
    logger.info(f"  → Resposta       : {emoji} {resposta.upper()}")
    if resposta == "aceito":
        logger.info(f"  → Horário conf.  : {dados.get('data_hora_confirmada')}")
    logger.info(f"  → Timestamp MOM  : {envelope.get('timestamp')}")
    logger.info("[AÇÃO] Notificando app da OFICINA sobre resposta do cliente...")
    logger.info("=" * 60)

    salvar_evento_no_banco(envelope, method.routing_key)
    channel.basic_ack(delivery_tag=method.delivery_tag)


# ── Mapa fila → handler ───────────────────────────────────────
HANDLERS = {
    "q.agendamento.criado":    handle_agendamento_criado,
    "q.agendamento.status":    handle_status_atualizado,
    "q.negociacao.proposta":   handle_negociacao_proposta,
    "q.negociacao.respondida": handle_negociacao_respondida,
}


# ── Entry point ───────────────────────────────────────────────
def iniciar_consumers():
    """
    Conecta ao RabbitMQ, declara a infraestrutura e
    registra todos os consumers em modo bloqueante.
    """
    logger.info("[MOM] Iniciando Autotrix Consumer — Sprint 2")
    logger.info(f"[MOM] Conectando em: {os.environ.get('RABBITMQ_URL', 'N/A')}")

    params     = pika.URLParameters(os.environ["RABBITMQ_URL"])
    params.heartbeat = 60
    connection = pika.BlockingConnection(params)
    channel    = connection.channel()

    declarar_infraestrutura(channel)

    # prefetch=1: processa uma mensagem por vez antes de dar ACK
    # garante que mensagens não se percam em caso de falha no meio do handler
    channel.basic_qos(prefetch_count=1)

    for fila in FILAS:
        channel.basic_consume(
            queue=fila["nome"],
            on_message_callback=HANDLERS[fila["nome"]],
        )
        logger.info(
            f"[MOM] Consumindo: '{fila['nome']}' — {fila['descricao']}"
        )

    logger.info("[MOM] Aguardando mensagens... (Ctrl+C para encerrar)")
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        logger.info("[MOM] Encerrando consumer...")
        channel.stop_consuming()
    finally:
        connection.close()
        logger.info("[MOM] Conexão encerrada.")


if __name__ == "__main__":
    iniciar_consumers()