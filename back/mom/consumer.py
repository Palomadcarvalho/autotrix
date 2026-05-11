"""
mom/consumer.py
─────────────────────────────────────────────────────────────────
Consumidores de eventos do Autotrix.

Este módulo demonstra como cada parte do sistema (app cliente,
app oficina, serviço de notificações) consome eventos do RabbitMQ.

Na arquitetura final (Sprints 3 e 4), os apps Flutter consultam
o backend via polling ou WebSocket, e o backend consulta as filas.
Este arquivo serve como referência e pode ser executado
separadamente como worker de background.

Para rodar:  python -m mom.consumer
─────────────────────────────────────────────────────────────────
"""

import os
import json
import logging

import pika
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

EXCHANGE_NAME = "autotrix.events"

# ── Definição das filas e seus bindings ──────────────────────
FILAS = [
    {
        "nome":        "q.agendamento.criado",
        "routing_key": "agendamento.criado",
        "descricao":   "App da OFICINA — recebe novos agendamentos dos clientes",
    },
    {
        "nome":        "q.agendamento.status",
        "routing_key": "agendamento.status.atualizado",
        "descricao":   "App do CLIENTE — recebe atualização de status do serviço",
    },
    {
        "nome":        "q.negociacao.proposta",
        "routing_key": "agendamento.negociacao.proposta",
        "descricao":   "App do CLIENTE — recebe proposta de horário alternativo da oficina",
    },
    {
        "nome":        "q.negociacao.respondida",
        "routing_key": "agendamento.negociacao.respondida",
        "descricao":   "App da OFICINA — sabe se o cliente aceitou ou recusou a negociação",
    },
]


def _declarar_infraestrutura(channel):
    channel.exchange_declare(
        exchange=EXCHANGE_NAME,
        exchange_type="topic",
        durable=True,
    )

    for fila in FILAS:
        # Declara a fila como durable (mensagens sobrevivem a restart)
        channel.queue_declare(queue=fila["nome"], durable=True)

        # Binding: conecta a fila ao exchange via routing key
        channel.queue_bind(
            exchange=EXCHANGE_NAME,
            queue=fila["nome"],
            routing_key=fila["routing_key"],
        )
        logger.info(f"[MOM] Fila '{fila['nome']}' → binding '{fila['routing_key']}'")


def handle_agendamento_criado(channel, method, properties, body):
    """
    Consumidor: App da OFICINA
    Acionado quando um cliente cria um novo agendamento.
    Na Sprint 3/4 → dispara push notification para a oficina.
    """
    dados = json.loads(body)
    logger.info(f"[OFICINA] Novo agendamento recebido: {dados}")
    # TODO (Sprint 3): enviar notificação push via Firebase / WebSocket
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_status_atualizado(channel, method, properties, body):
    """
    Consumidor: App do CLIENTE
    Acionado quando a oficina muda o status do agendamento.
    """
    dados = json.loads(body)
    logger.info(f"[CLIENTE] Status atualizado: {dados}")
    # TODO (Sprint 3): atualizar estado local do app Flutter
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_negociacao_proposta(channel, method, properties, body):
    """
    Consumidor: App do CLIENTE
    Acionado quando a oficina propõe um horário alternativo.
    O cliente verá a proposta e poderá aceitar ou recusar.
    """
    dados = json.loads(body)
    logger.info(f"[CLIENTE] Proposta de negociação recebida: {dados}")
    # TODO (Sprint 3): exibir modal de negociação no app do cliente
    channel.basic_ack(delivery_tag=method.delivery_tag)


def handle_negociacao_respondida(channel, method, properties, body):
    dados = json.loads(body)
    logger.info(f"[OFICINA] Resposta de negociação recebida: {dados}")
    channel.basic_ack(delivery_tag=method.delivery_tag)


HANDLERS = {
    "q.agendamento.criado":   handle_agendamento_criado,
    "q.agendamento.status":   handle_status_atualizado,
    "q.negociacao.proposta":  handle_negociacao_proposta,
    "q.negociacao.respondida": handle_negociacao_respondida,
}


def iniciar_consumers():
    params = pika.URLParameters(os.environ["RABBITMQ_URL"])
    connection = pika.BlockingConnection(params)
    channel    = connection.channel()

    _declarar_infraestrutura(channel)

    channel.basic_qos(prefetch_count=1)

    for fila in FILAS:
        channel.basic_consume(
            queue=fila["nome"],
            on_message_callback=HANDLERS[fila["nome"]],
        )
        logger.info(f"[MOM] Consumindo fila '{fila['nome']}' — {fila['descricao']}")

    logger.info("[MOM] Aguardando mensagens... (Ctrl+C para encerrar)")
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        channel.stop_consuming()
    finally:
        connection.close()


if __name__ == "__main__":
    iniciar_consumers()
