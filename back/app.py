import os
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

import database
from routes.clientes         import clientes_bp
from routes.veiculos         import veiculos_bp
from routes.servicos         import servicos_bp
from routes.agendamentos     import agendamentos_bp
from routes.disponibilidades import disponibilidades_bp
from routes.eventos          import eventos_bp

load_dotenv()

app = Flask(__name__)
CORS(app)

database.init_app(app)

app.register_blueprint(clientes_bp,          url_prefix="/api/clientes")
app.register_blueprint(veiculos_bp,           url_prefix="/api/veiculos")
app.register_blueprint(servicos_bp,           url_prefix="/api/servicos")
app.register_blueprint(agendamentos_bp,       url_prefix="/api/agendamentos")
app.register_blueprint(disponibilidades_bp,   url_prefix="/api/disponibilidades")
app.register_blueprint(eventos_bp,            url_prefix="/api/eventos")


@app.route("/")
def index():
    return {
        "sistema": "Autotrix API",
        "versao":  "2.0.0",
        "sprint":  "2 — MOM integrado",
        "banco":   "PostgreSQL",
        "mom":     "RabbitMQ (topic exchange: autotrix.events)",
        "endpoints": {
            "clientes":          "/api/clientes",
            "veiculos":          "/api/veiculos",
            "servicos":          "/api/servicos",
            "agendamentos":      "/api/agendamentos",
            "disponibilidades":  "/api/disponibilidades",
            "eventos":           "/api/eventos",
        },
    }


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        debug=os.getenv("FLASK_ENV") == "development",
        port=5000,
    )