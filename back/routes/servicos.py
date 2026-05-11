from flask import Blueprint, request, jsonify
from database import get_db

servicos_bp = Blueprint("servicos", __name__)


@servicos_bp.route("/", methods=["GET"])
def listar():
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM servicos ORDER BY nome")
    return jsonify([dict(r) for r in cur.fetchall()])


@servicos_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM servicos WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Serviço não encontrado"}), 404
    return jsonify(dict(row))


@servicos_bp.route("/", methods=["POST"])
def criar():
    data = request.get_json()
    for campo in ["nome", "duracao_min", "preco"]:
        if data.get(campo) is None:
            return jsonify({"erro": f"Campo '{campo}' é obrigatório"}), 400
    db  = get_db()
    cur = db.cursor()
    cur.execute("""
        INSERT INTO servicos (nome, descricao, duracao_min, preco)
        VALUES (%s, %s, %s, %s) RETURNING *
    """, (data["nome"], data.get("descricao", ""), data["duracao_min"], data["preco"]))
    novo = dict(cur.fetchone())
    db.commit()
    return jsonify(novo), 201


@servicos_bp.route("/<int:id>", methods=["PUT"])
def atualizar(id):
    data = request.get_json()
    db   = get_db()
    cur  = db.cursor()
    cur.execute("SELECT * FROM servicos WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Serviço não encontrado"}), 404
    row = dict(row)
    cur.execute("""
        UPDATE servicos SET nome = %s, descricao = %s, duracao_min = %s, preco = %s
        WHERE id = %s RETURNING *
    """, (
        data.get("nome",        row["nome"]),
        data.get("descricao",   row["descricao"]),
        data.get("duracao_min", row["duracao_min"]),
        data.get("preco",       row["preco"]),
        id,
    ))
    atualizado = dict(cur.fetchone())
    db.commit()
    return jsonify(atualizado)