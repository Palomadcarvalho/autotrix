import os
import bcrypt
from flask import Blueprint, request, jsonify
from database import get_db

oficina_bp = Blueprint("oficina", __name__)


@oficina_bp.route("/login", methods=["POST"])
def login():
    data  = request.get_json()
    email = data.get("email", "").strip().lower()
    senha = data.get("senha", "")

    if not email or not senha:
        return jsonify({"erro": "Credenciais inválidas"}), 401

    email_env = os.environ.get("OFICINA_EMAIL", "").strip().lower()
    senha_env = os.environ.get("OFICINA_SENHA", "")

    if not email_env or not senha_env:
        return jsonify({"erro": "Oficina não configurada no servidor"}), 500

    if email != email_env or senha != senha_env:
        return jsonify({"erro": "Credenciais inválidas"}), 401

    return jsonify({
        "id":    0,
        "nome":  os.environ.get("OFICINA_NOME", "Autotrix Oficina"),
        "email": email_env,
        "tipo":  "oficina",
    })


@oficina_bp.route("/agendamentos", methods=["GET"])
def listar_agendamentos():

    db     = get_db()
    cur    = db.cursor()
    status = request.args.get("status")

    query = """
        SELECT
            a.*,
            c.nome        AS cliente_nome,
            c.telefone    AS cliente_telefone,
            v.placa,
            v.modelo,
            v.marca,
            v.ano,
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
        lista = [s.strip() for s in status.split(",")]
        placeholders = ",".join(["%s"] * len(lista))
        query += f" AND a.status IN ({placeholders})"
        params.extend(lista)

    query += " ORDER BY a.data_hora ASC"

    cur.execute(query, params)
    return jsonify([dict(r) for r in cur.fetchall()])


@oficina_bp.route("/agendamentos/<int:id>/status", methods=["PATCH"])
def atualizar_status(id):
    from mom.publisher import publicar_evento, RoutingKey

    STATUS_VALIDOS = [
        "pendente", "negociacao", "confirmado",
        "em_andamento", "concluido", "cancelado",
    ]

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

    row                = dict(row)
    data_hora_sugerida = row["data_hora_sugerida"]
    data_hora_final    = row["data_hora"]

    if novo_status == "negociacao":
        sugerida = data.get("data_hora_sugerida")
        if not sugerida:
            return jsonify({
                "erro": "Para 'negociacao' informe 'data_hora_sugerida'"
            }), 400
        data_hora_sugerida = sugerida
        publicar_evento(
            RoutingKey.NEGOCIACAO_PROPOSTA,
            {
                "agendamento_id":     id,
                "cliente_id":         row["cliente_id"],
                "data_hora_original": str(row["data_hora"]),
                "data_hora_sugerida": sugerida,
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

    if novo_status != "negociacao":
        publicar_evento(
            RoutingKey.AGENDAMENTO_STATUS_ATUALIZADO,
            {
                "agendamento_id":  id,
                "cliente_id":      row["cliente_id"],
                "status_anterior": row["status"],
                "status_novo":     novo_status,
            },
        )

    return jsonify({
        "mensagem":    f"Status atualizado para '{novo_status}'",
        "agendamento": atualizado,
    })