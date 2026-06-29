import os
import json
import logging
from datetime import datetime, timezone

import pika

logger = logging.getLogger(__name__)

EXCHANGE_NAME = "autotrix.events"
EXCHANGE_TYPE = "topic"

class RoutingKey:
    AGENDAMENTO_CRIADO           = "agendamento.criado"
    AGENDAMENTO_STATUS_ATUALIZADO = "agendamento.status.atualizado"
    NEGOCIACAO_PROPOSTA          = "agendamento.negociacao.proposta"
    NEGOCIACAO_RESPONDIDA        = "agendamento.negociacao.respondida"


def _get_connection() -> pika.BlockingConnection:
    """Abre uma nova conexão AMQP com o RabbitMQ."""
    params = pika.URLParameters(os.environ["RABBITMQ_URL"])
    params.heartbeat = 60
    params.blocked_connection_timeout = 30
    return pika.BlockingConnection(params)


def _build_channel(connection: pika.BlockingConnection) -> pika.adapters.blocking_connection.BlockingChannel:

    channel = connection.channel()
    channel.exchange_declare(
        exchange=EXCHANGE_NAME,
        exchange_type=EXCHANGE_TYPE,
        durable=True,
    )
    return channel


def publicar_evento(routing_key: str, payload: dict) -> None:

    envelope = {
        "evento": routing_key,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "dados": payload,
    }

    body = json.dumps(envelope, ensure_ascii=False, default=str)

    try:
        connection = _get_connection()
        channel    = _build_channel(connection)

        channel.basic_publish(
            exchange=EXCHANGE_NAME,
            routing_key=routing_key,
            body=body.encode("utf-8"),
            properties=pika.BasicProperties(
                content_type="application/json",
                delivery_mode=2,   
            ),
        )

        logger.info(f"[MOM] Evento publicado → {routing_key} | payload: {body}")
        connection.close()

    except Exception as exc:
        logger.error(f"[MOM] Falha ao publicar evento '{routing_key}': {exc}")
