from flask import Blueprint, request, jsonify
from database import get_db

veiculos_bp = Blueprint("veiculos", __name__)


@veiculos_bp.route("/", methods=["GET"])
def listar():
    db  = get_db()
    cur = db.cursor()
    cliente_id = request.args.get("cliente_id")
    if cliente_id:
        cur.execute("SELECT * FROM veiculos WHERE cliente_id = %s", (cliente_id,))
    else:
        cur.execute("SELECT * FROM veiculos")
    return jsonify([dict(r) for r in cur.fetchall()])


@veiculos_bp.route("/<int:id>", methods=["GET"])
def buscar(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT * FROM veiculos WHERE id = %s", (id,))
    row = cur.fetchone()
    if not row:
        return jsonify({"erro": "Veículo não encontrado"}), 404
    return jsonify(dict(row))


@veiculos_bp.route("/", methods=["POST"])
def criar():
    data = request.get_json()
    for campo in ["cliente_id", "marca", "modelo", "ano", "placa"]:
        if not data.get(campo):
            return jsonify({"erro": f"Campo '{campo}' é obrigatório"}), 400
    db  = get_db()
    cur = db.cursor()
    try:
        cur.execute("""
            INSERT INTO veiculos (cliente_id, marca, modelo, ano, placa)
            VALUES (%s, %s, %s, %s, %s) RETURNING *
        """, (data["cliente_id"], data["marca"], data["modelo"], data["ano"], data["placa"]))
        novo = dict(cur.fetchone())
        db.commit()
        return jsonify(novo), 201
    except Exception as e:
        db.rollback()
        return jsonify({"erro": str(e)}), 400


@veiculos_bp.route("/<int:id>", methods=["DELETE"])
def remover(id):
    db  = get_db()
    cur = db.cursor()
    cur.execute("SELECT id FROM veiculos WHERE id = %s", (id,))
    if not cur.fetchone():
        return jsonify({"erro": "Veículo não encontrado"}), 404
    cur.execute("DELETE FROM veiculos WHERE id = %s", (id,))
    db.commit()
    return jsonify({"mensagem": "Veículo removido"})