# 🚗 Autotrix

Plataforma de agendamento de serviços mecânicos que conecta clientes e oficinas de forma prática, desenvolvida como projeto integrador da disciplina **Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas** — PUC Minas, Engenharia de Software, 1º Semestre 2026.

---

## 📋 Sobre o projeto

Oficinas mecânicas de pequeno e médio porte ainda dependem de ligações, WhatsApp e atendimento presencial para gerenciar seus agendamentos. Isso gera conflitos de horário, interrupções constantes no trabalho da equipe e dificuldade para o cliente saber se o serviço foi aceito.

O Autotrix resolve esse problema: a oficina cadastra seus horários disponíveis e o cliente agenda de forma autônoma. O sistema suporta também um fluxo de **negociação de horários**, a oficina pode propor um horário alternativo e o cliente aceita ou recusa, tudo dentro da plataforma.

### Perfis

| Perfil | O que pode fazer |
|---|---|
| **Cliente** | Criar conta, cadastrar veículo, visualizar horários, agendar serviços, acompanhar status, aceitar ou recusar negociações |
| **Oficina** | Login com credenciais fixas, cadastrar disponibilidades, confirmar ou recusar agendamentos, propor negociação, atualizar andamento e concluir serviços |

---

## 🗂️ Estrutura do repositório

```
autotrix/
│
├── docker-compose.yml          # Orquestra os 4 containers
├── .env                        # Credenciais
├── .env.example                # Modelo de variáveis
├── .gitignore
├── README.md
│
├── back/                       # Backend Flask (Python)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   ├── database.py
│   ├── websocket_server.py
│   ├── routes/
│   │   ├── clientes.py         # CRUD + login com bcrypt
│   │   ├── veiculos.py
│   │   ├── servicos.py
│   │   ├── agendamentos.py
│   │   ├── disponibilidades.py
│   │   ├── eventos.py
│   │   └── oficina.py          # Login e gestão pela oficina
│   ├── mom/
│   │   ├── publisher.py        # Publica eventos no RabbitMQ
│   │   └── consumer.py         # Consome filas e persiste em eventos_log
│   └── sql/
│       ├── init.sql
│       ├── migration_sprint2.sql
│       └── migration_sprint3.sql
│
└── mobile/
    ├── cliente/                # App Flutter do cliente (Sprint 3)
    │   └── lib/
    │       ├── main.dart
    │       ├── models/
    │       ├── services/
    │       ├── widgets/
    │       └── screens/
    └── oficina/                # App Flutter da oficina (Sprint 4)
        └── lib/
            ├── main.dart
            ├── models/
            ├── services/
            ├── widgets/
            └── screens/
```

---

## ⚙️ Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e rodando
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x instalado
- [Android Studio](https://developer.android.com/studio) com emulador configurado (opcional)

---

## 🚀 Como executar

### 1. Clone o repositório

```bash
git clone https://github.com/seu-usuario/autotrix.git
cd autotrix
```

### 2. Configure as variáveis de ambiente

```bash
cp .env.example .env
```

O `.env` já vem com valores padrão para desenvolvimento. Edite se quiser mudar as credenciais.

### 3. Suba o backend

```bash
docker compose up --build
```

Aguarda os 4 containers ficarem saudáveis:

```
autotrix_db        → PostgreSQL :5432     (healthy)
autotrix_rabbitmq  → RabbitMQ  :5672      (healthy)
autotrix_backend   → Flask API :5000      (running)
autotrix_consumer  → Consumer MOM         (running)
```

**Verifique:**
- API: http://localhost:5000
- RabbitMQ: http://localhost:15672 (login: `autotrix_mq` / `autotrix_mq_pass`)

---

### 4. App do Cliente

```bash
cd mobile/cliente
flutter pub get
```

**Rodando no emulador Android:**
```bash
# Inicie o emulador no Android Studio antes
flutter run
```

**Rodando no navegador (Edge/Chrome):**
```bash
flutter create --platforms=web .   # só na primeira vez
flutter run -d edge
```

> Se rodar no Edge, confirme que `api_service.dart` e `websocket_service.dart` usam `localhost` em vez de `10.0.2.2`.

**Fluxo do cliente:**
1. Abra o app → Splash azul → Tela de Login
2. Crie uma conta em "Criar conta"
3. Cadastre seu veículo
4. Na tela principal, toque em "Novo agendamento"
5. Selecione serviço, veículo e horário disponível
6. Acompanhe o status em tempo real

---

### 5. App da Oficina

```bash
cd mobile/oficina
flutter pub get
```

**Rodando no navegador:**
```bash
flutter create --platforms=web .   # só na primeira vez
flutter run -d edge
```

**Rodando no emulador:**
```bash
flutter run
```

> Se rodar no Edge, confirme que `oficina_service.dart` e `disponibilidade_screen.dart` usam `localhost`.

**Credenciais de acesso:**
```
E-mail: oficina@autotrix.com
Senha:  oficina123
```

**Fluxo da oficina:**
1. Abra o app → Splash laranja → Tela de Login
2. Entre com as credenciais acima
3. Toque no ícone de calendário para cadastrar horários disponíveis
4. Volte para "Solicitações", novos agendamentos aparecem a cada 10 segundos
5. Toque em um agendamento para confirmar, recusar ou propor negociação
6. Acompanhe o andamento e marque como concluído

---

## 🔄 Fluxo completo de ponta a ponta

```
Cliente cria agendamento
        ↓
Backend salva no PostgreSQL
        ↓
Publisher publica "agendamento.criado" no RabbitMQ
        ↓
Consumer processa e persiste em eventos_log
        ↓
App da oficina detecta via polling (10s) → exibe em Pendentes
        ↓
Oficina confirma (ou propõe negociação)
        ↓
Publisher publica "agendamento.status.atualizado"
        ↓
App do cliente recebe via WebSocket → atualiza status em tempo real
```

---

## 🗃️ Banco de dados

**5 tabelas principais:**

| Tabela | Descrição |
|---|---|
| `clientes` | Usuários do app cliente com senha em bcrypt |
| `veiculos` | Veículos vinculados a cada cliente |
| `servicos` | Catálogo de serviços da oficina |
| `disponibilidades` | Horários disponíveis cadastrados pela oficina |
| `agendamentos` | Entidade central — une cliente, veículo, serviço e horário |

**Status do agendamento:**
```
pendente → confirmado → em_andamento → concluido
        ↘ negociacao ↗
        ↘ cancelado
```

---

## 🔌 Endpoints da API

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/api/clientes/` | Criar conta |
| `POST` | `/api/clientes/login` | Login do cliente |
| `POST` | `/api/oficina/login` | Login da oficina |
| `GET` | `/api/oficina/agendamentos` | Listar agendamentos (oficina) |
| `PATCH` | `/api/oficina/agendamentos/<id>/status` | Atualizar status |
| `GET/POST` | `/api/disponibilidades/` | Gerenciar horários |
| `POST` | `/api/agendamentos/` | Criar agendamento |
| `GET` | `/api/eventos/resumo` | Histórico do MOM |
| `WS` | `/ws/<cliente_id>` | WebSocket tempo real |

---

## 🛠️ Tecnologias

| Tecnologia | Uso |
|---|---|
| Python 3.12 + Flask | Backend REST |
| PostgreSQL 16 | Banco de dados |
| RabbitMQ 3.13 | Message broker (MOM) |
| bcrypt | Hash de senhas |
| Flask-Sock | WebSocket |
| Docker Compose | Orquestração |
| Flutter 3.x / Dart | Apps móveis |
| shared_preferences | Persistência local no Flutter |

---

## 📅 Sprints

| Sprint | Entrega | Prazo |
|---|---|---|
| Sprint 1 | Backend REST + PostgreSQL + Docker | 11/05/2026 |
| Sprint 2 | Integração MOM (RabbitMQ) | 25/05/2026 |
| Sprint 3 | App Flutter — Cliente | 15/06/2026 |
| Sprint 4 | App Flutter — Oficina + Integração Final | 03/07/2026 |

---

## 📚 Referências

- MARTIN, Robert C. *Arquitetura limpa*. Alta Books, 2019.
- BAILEY, Thomas. *Flutter for beginners*. 3rd ed. Packt, 2023.
- HOHPE, G.; WOOLF, B. *Enterprise Integration Patterns*. Addison-Wesley, 2003.
- RICHARDSON, Chris. *Microservices patterns*. Manning, 2018.
- COULOURIS, George et al. *Distributed Systems: concepts and design*. 5th ed. Addison-Wesley, 2011.

---

## 👩‍💻 Autora

**[Paloma Dias de Carvalho]** — Engenharia de Software, PUC Minas, 5º Período
Disciplina: Lab. de Desenvolvimento de Aplicações Móveis e Distribuídas
Professores: Cleiton Silva Tavares e Cristiano de Macedo Neto
1º Semestre 2026
