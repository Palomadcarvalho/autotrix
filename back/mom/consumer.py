import os
import json
import logging
import psycopg2
import psycopg2.extras
import pika
from datetime import datetime, timezone
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

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


def get_pg_connection():
    return psycopg2.connect(
        os.environ["DATABASE_URL"],
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def salvar_evento_no_banco(envelope: dict, fila: str):
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


def declarar_infraestrutura(channel):
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



def handle_agendamento_criado(channel, method, properties, body):

    envelope = json.loads(body)
    dados    = envelope.get("dados", {})

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

    salvar_evento_no_banco(envelope, method.routing_key)

    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_status_atualizado(channel, method, properties, body):

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


HANDLERS = {
    "q.agendamento.criado":    handle_agendamento_criado,
    "q.agendamento.status":    handle_status_atualizado,
    "q.negociacao.proposta":   handle_negociacao_proposta,
    "q.negociacao.respondida": handle_negociacao_respondida,
}


def iniciar_consumers():
    logger.info("[MOM] Iniciando Autotrix Consumer — Sprint 2")
    logger.info(f"[MOM] Conectando em: {os.environ.get('RABBITMQ_URL', 'N/A')}")

    params     = pika.URLParameters(os.environ["RABBITMQ_URL"])
    params.heartbeat = 60
    connection = pika.BlockingConnection(params)
    channel    = connection.channel()

    declarar_infraestrutura(channel)

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