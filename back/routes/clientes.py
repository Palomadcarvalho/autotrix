from flask import Blueprint, request, jsonify
from database import get_db

clientes_bp = Blueprint("clientes", __name__)


@clientes_bp.route("/", methods=["GET"])
def listar():
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM clientes ORDER BY nome")
    return jsonify([dict(r) for r in cur.fetchall()])


@clientes_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM clientes WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Cliente não encontrado"}), 404
    return jsonify(dict(row))


@clientes_bp.route("/", methods=["POST"])
def criar():
    data = request.get_json()
    for campo in ["nome", "email", "telefone"]:
        if not data.get(campo):
            return jsonify({"erro": f"Campo '{campo}' é obrigatório"}), 400
    db  = get_db()
    cur = db.cursor()
    try:
        cur.execute("""
            INSERT INTO clientes (nome, email, telefone)
            VALUES (%s, %s, %s) RETURNING *
        """, (data["nome"], data["email"], data["telefone"]))
        novo = dict(cur.fetchone())
        db.commit()
        return jsonify(novo), 201
    except Exception as e:
        db.rollback()
        return jsonify({"erro": str(e)}), 400


@clientes_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    data = request.get_json()
    db   = get_db()
    cur  = db.cursor()
    cur.execute("SELECT * FROM clientes WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Cliente não encontrado"}), 404
    row = dict(row)
    cur.execute("""
        UPDATE clientes SET nome = %s, email = %s, telefone = %s
        WHERE id = %s RETURNING *
    """, (
        data.get("nome",     row["nome"]),
        data.get("email",    row["email"]),
        data.get("telefone", row["telefone"]),
        id,
    ))
    atualizado = dict(cur.fetchone())
    db.commit()
    return jsonify(atualizado)


@clientes_bp.route("/<int:id>", methods=["DELETE"])
def remover(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT id FROM clientes WHERE id = %s", (id,))
    if not cur.fetchone():
        return jsonify({"erro": "Cliente não encontrado"}), 404
    cur.execute("DELETE FROM clientes WHERE id = %s", (id,))
    db.commit()
    return jsonify({"mensagem": "Cliente removido"})