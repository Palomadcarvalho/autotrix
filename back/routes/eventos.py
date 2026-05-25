"""
routes/eventos.py
Endpoint de consulta ao histórico de eventos processados pelo consumer.
Útil para demonstração e evidência da Sprint 2.
"""

from flask import Blueprint, request, jsonify
from database import get_db

eventos_bp = Blueprint("eventos", __name__)


@eventos_bp.route("/", methods=["GET"])
def listar():
    """
    GET /api/eventos/
    Lista os eventos processados pelo consumer MOM.
    Aceita filtros: ?evento=agendamento.criado  ?agendamento_id=1
    """
    db  = get_db()
    cur = db.cursor()

    evento         = request.args.get("evento")
    agendamento_id = request.args.get("agendamento_id")

    query  = "SELECT * FROM eventos_log WHERE 1=1"
    params = []

    if evento:
        query += " AND evento = %s"
        params.append(evento)
    if agendamento_id:
        query += " AND agendamento_id = %s"
        params.append(agendamento_id)

    query += " ORDER BY processado_em DESC LIMIT 100"

    cur.execute(query, params)
    return jsonify([dict(r) for r in cur.fetchall()])


@eventos_bp.route("/resumo", methods=["GET"])
def resumo():
    """
    GET /api/eventos/resumo
    Retorna contagem de eventos por tipo — útil para evidência.
    """
    db  = get_db()
    cur = db.cursor()
    cur.execute("""
        SELECT
            evento,
            fila,
            COUNT(*)            AS total,
            MAX(processado_em)  AS ultimo_em
        FROM eventos_log
        GROUP BY evento, fila
        ORDER BY total DESC
    """)
    return jsonify([dict(r) for r in cur.fetchall()])