from flask import Blueprint, request, jsonify
from database import get_db

disponibilidades_bp = Blueprint("disponibilidades", __name__)

SELECT_COLS = """
    id,
    data::text          AS data,
    hora_inicio::text   AS hora_inicio,
    hora_fim::text      AS hora_fim,
    vagas,
    criado_em
"""


@disponibilidades_bp.route("/", methods=["GET"])
def listar():
    db  = get_db()
    cur = db.cursor()
    data = request.args.get("data")
    if data:
        cur.execute(
            f"SELECT {SELECT_COLS} FROM disponibilidades WHERE data = %s ORDER BY hora_inicio",
            (data,)
        )
    else:
        cur.execute(f"SELECT {SELECT_COLS} FROM disponibilidades ORDER BY data, hora_inicio")
    return jsonify([dict(r) for r in cur.fetchall()])


@disponibilidades_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute(f"SELECT {SELECT_COLS} FROM disponibilidades WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Disponibilidade não encontrada"}), 404
    return jsonify(dict(row))


@disponibilidades_bp.route("/", methods=["POST"])
def criar():
    data = request.get_json()
    for campo in ["data", "hora_inicio", "hora_fim"]:
        if not data.get(campo):
            return jsonify({"erro": f"Campo '{campo}' é obrigatório"}), 400
    vagas = data.get("vagas", 1)
    if not isinstance(vagas, int) or vagas < 1:
        return jsonify({"erro": "'vagas' deve ser um inteiro positivo"}), 400

    db  = get_db()
    cur = db.cursor()
    cur.execute(f"""
        INSERT INTO disponibilidades (data, hora_inicio, hora_fim, vagas)
        VALUES (%s, %s, %s, %s)
        RETURNING {SELECT_COLS}
    """, (data["data"], data["hora_inicio"], data["hora_fim"], vagas))
    novo = dict(cur.fetchone())
    db.commit()
    return jsonify(novo), 201


@disponibilidades_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    data = request.get_json()
    db   = get_db()
    cur  = db.cursor()
    cur.execute(f"SELECT {SELECT_COLS} FROM disponibilidades WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Disponibilidade não encontrada"}), 404
    row = dict(row)
    cur.execute(f"""
        UPDATE disponibilidades
        SET data = %s, hora_inicio = %s, hora_fim = %s, vagas = %s
        WHERE id = %s
        RETURNING {SELECT_COLS}
    """, (
        data.get("data",        row["data"]),
        data.get("hora_inicio", row["hora_inicio"]),
        data.get("hora_fim",    row["hora_fim"]),
        data.get("vagas",       row["vagas"]),
        id,
    ))
    atualizado = dict(cur.fetchone())
    db.commit()
    return jsonify(atualizado)


@disponibilidades_bp.route("/<int:id>", methods=["DELETE"])
def remover(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT id FROM disponibilidades WHERE id = %s", (id,))
    if not cur.fetchone():
        return jsonify({"erro": "Disponibilidade não encontrada"}), 404
    cur.execute("DELETE FROM disponibilidades WHERE id = %s", (id,))
    db.commit()
    return jsonify({"mensagem": "Disponibilidade removida"})