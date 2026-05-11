"""
routes/agendamentos.py
CRUD de agendamentos + fluxo de negociação.
Publica eventos no RabbitMQ após cada operação relevante.
"""

from flask import Blueprint, request, jsonify
from database import get_db
from mom.publisher import publicar_evento, RoutingKey

agendamentos_bp = Blueprint("agendamentos", __name__)

STATUS_VALIDOS = [
    "pendente", "negociacao", "confirmado",
    "em_andamento", "concluido", "cancelado",
]


def _row_to_dict(row):
    return dict(row) if row else None


# ── GET /api/agendamentos/
@agendamentos_bp.route("/", methods=["GET"])
def listar():
    status     = request.args.get("status")
    cliente_id = request.args.get("cliente_id")

    query = """
        SELECT
            a.*,
            c.nome        AS cliente_nome,
            v.placa,
            v.modelo,
            s.nome        AS servico_nome,
            s.preco,
            s.duracao_min
        FROM agendamentos a
        JOIN clientes c ON c.id = a.cliente_id
        JOIN veiculos v ON v.id = a.veiculo_id
        JOIN servicos s ON s.id = a.servico_id
        WHERE 1=1
    """
    params = []

    if status:
        query += " AND a.status = %s"
        params.append(status)
    if cliente_id:
        query += " AND a.cliente_id = %s"
        params.append(cliente_id)

    query += " ORDER BY a.data_hora"

    db  = get_db()
    cur = db.cursor()
    cur.execute(query, params)
    return jsonify([dict(r) for r in cur.fetchall()])


# ── GET /api/agendamentos/<id>
@agendamentos_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("""
        SELECT
            a.*,
            c.nome        AS cliente_nome,
            v.placa, v.modelo,
            s.nome        AS servico_nome,
            s.preco, s.duracao_min
        FROM agendamentos a
        JOIN clientes c ON c.id = a.cliente_id
        JOIN veiculos v ON v.id = a.veiculo_id
        JOIN servicos s ON s.id = a.servico_id
        WHERE a.id = %s
    """, (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Agendamento não encontrado"}), 404
    return jsonify(dict(row))


# ── POST /api/agendamentos/
@agendamentos_bp.route("/", methods=["POST"])
def criar():
    data = request.get_json()

    for campo in ["cliente_id", "veiculo_id", "servico_id", "data_hora"]:
        if not data.get(campo):
            return jsonify({"erro": f"Campo '{campo}' é obrigatório"}), 400

    db  = get_db()
    cur = db.cursor()
    cur.execute("""
        INSERT INTO agendamentos (cliente_id, veiculo_id, servico_id, data_hora, observacoes)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING *
    """, (
        data["cliente_id"], data["veiculo_id"], data["servico_id"],
        data["data_hora"], data.get("observacoes", ""),
    ))
    novo = dict(cur.fetchone())
    db.commit()

    # ── Evento MOM: notifica a oficina de novo agendamento
    publicar_evento(
        RoutingKey.AGENDAMENTO_CRIADO,
        {
            "agendamento_id": novo["id"],
            "cliente_id":     novo["cliente_id"],
            "veiculo_id":     novo["veiculo_id"],
            "servico_id":     novo["servico_id"],
            "data_hora":      str(novo["data_hora"]),
            "observacoes":    novo["observacoes"],
        },
    )

    return jsonify(novo), 201


# ── PATCH /api/agendamentos/<id>/status
@agendamentos_bp.route("/<int:id>/status", methods=["PATCH"])
def atualizar_status(id):
    data        = request.get_json()
    novo_status = data.get("status")

    if novo_status not in STATUS_VALIDOS:
        return jsonify({"erro": f"Status inválido. Aceitos: {STATUS_VALIDOS}"}), 400

    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM agendamentos WHERE id = %s", (id,))
    row = cur.fetchone()

    if not row:
        return jsonify({"erro": "Agendamento não encontrado"}), 404

    row = dict(row)
    data_hora_sugerida = row["data_hora_sugerida"]
    data_hora_final    = row["data_hora"]

    # Oficina propõe horário alternativo
    if novo_status == "negociacao":
        sugerida = data.get("data_hora_sugerida")
        if not sugerida:
            return jsonify({
                "erro": "Para status 'negociacao' informe 'data_hora_sugerida'"
            }), 400
        data_hora_sugerida = sugerida

        # ── Evento MOM: cliente recebe a proposta
        publicar_evento(
            RoutingKey.NEGOCIACAO_PROPOSTA,
            {
                "agendamento_id":     id,
                "cliente_id":         row["cliente_id"],
                "data_hora_original": str(row["data_hora"]),
                "data_hora_sugerida": sugerida,
            },
        )

    # Cliente aceita negociação → promove horário sugerido
    if novo_status == "confirmado" and row["status"] == "negociacao":
        if row["data_hora_sugerida"]:
            data_hora_final    = row["data_hora_sugerida"]
            data_hora_sugerida = None

        # ── Evento MOM: oficina sabe que cliente aceitou
        publicar_evento(
            RoutingKey.NEGOCIACAO_RESPONDIDA,
            {
                "agendamento_id": id,
                "resposta":       "aceito",
                "data_hora_confirmada": str(data_hora_final),
            },
        )

    # Cliente recusa negociação
    if novo_status == "cancelado" and row["status"] == "negociacao":
        publicar_evento(
            RoutingKey.NEGOCIACAO_RESPONDIDA,
            {
                "agendamento_id": id,
                "resposta":       "recusado",
            },
        )

    cur.execute("""
        UPDATE agendamentos
        SET status = %s, data_hora_sugerida = %s, data_hora = %s
        WHERE id = %s
        RETURNING *
    """, (novo_status, data_hora_sugerida, data_hora_final, id))
    atualizado = dict(cur.fetchone())
    db.commit()

    # ── Evento MOM
    if novo_status not in ("negociacao",):
        publicar_evento(
            RoutingKey.AGENDAMENTO_STATUS_ATUALIZADO,
            {
                "agendamento_id": id,
                "cliente_id":     row["cliente_id"],
                "status_anterior": row["status"],
                "status_novo":    novo_status,
            },
        )

    return jsonify({"mensagem": f"Status → '{novo_status}'", "agendamento": atualizado})


# ── DELETE /api/agendamentos/<id>
@agendamentos_bp.route("/<int:id>", methods=["DELETE"])
def cancelar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT id, cliente_id, status FROM agendamentos WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Agendamento não encontrado"}), 404

    cur.execute(
        "UPDATE agendamentos SET status = 'cancelado' WHERE id = %s", (id,)
    )
    db.commit()

    publicar_evento(
        RoutingKey.AGENDAMENTO_STATUS_ATUALIZADO,
        {"agendamento_id": id, "cliente_id": row["cliente_id"], "status_novo": "cancelado"},
    )

    return jsonify({"mensagem": "Agendamento cancelado"})
