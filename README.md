# autotrix
---
**Disciplina:** Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas  
**Curso:** Engenharia de Software — PUC Minas  
**Professor:** Cleiton da Silva Tavares  
**Aluna:** Paloma Dias de Carvalho   

---

## Contexto e Motivação

O autotrix é uma plataforma de agendamento de serviços mecânicos que conecta clientes e oficinas de forma prática e rápida, com apenas alguns cliques.

Atualmente, grande parte das oficinas ainda utiliza métodos tradicionais de agendamento, como atendimento presencial, ligações telefônicas ou mensagens via WhatsApp. Esse processo exige uma troca constante de comunicação entre o cliente e o responsável pela oficina, o que pode gerar demora no atendimento, interrupções nas atividades da equipe e dificuldades na organização da agenda.

O objetivo do autotrix é simplificar esse processo, tornando o agendamento mais eficiente e confortável para ambas as partes. A plataforma permite que a oficina cadastre previamente suas datas e horários disponíveis no sistema, possibilitando que o próprio cliente realize o agendamento de forma automática, sem depender de atendimento manual.

Além disso, o sistema também oferece flexibilidade nas negociações: o cliente pode enviar uma proposta de agendamento para análise da oficina, assim como a própria oficina pode sugerir horários alternativos para que o cliente aceite a melhor opção. Dessa forma, o autotrix contribui para a otimização da gestão da oficina e melhora significativamente a experiência do cliente.

---

## Perfis de usuário
| Perfil | Responsabilidades |
|---|---|
| **Cliente** | Visualiza horários disponíveis, solicita agendamentos, aceita ou recusa negociações, acompanha o status do serviço |
| **Prestador (oficina)** | Cadastra disponibilidades, confirma ou propõe horários alternativos (negociação), atualiza o andamento dos serviços |

## Estrutura do repositório

```
autotrix/
│
├── docker-compose.yml          
├── .env                        
├── .env.example                
│
├── back/                       
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                 
│   ├── database.py             
│   │
│   ├── routes/
│   │   ├── clientes.py
│   │   ├── veiculos.py
│   │   ├── servicos.py
│   │   ├── disponibilidades.py
│   │   └── agendamentos.py     # Fluxo central + integração MOM
│   │
│   ├── mom/
│   │   ├── publisher.py        # Publica eventos no RabbitMQ
│   │   └── consumer.py         # Consome eventos (Sprint 2)
│   │
│   └── sql/
│       └── init.sql            # Schema PostgreSQL + dados iniciais
│
└── mobile/                     # Aplicativos Flutter
    ├── cliente/                # Sprint 3 — app do cliente
    └── oficina/                # Sprint 4 — app da oficina
```

---
## Arquitetura
```
┌──────────────────────────────────────────────────────────────────┐
│  Dispositivos (fora do Docker)                                   │
│  📱 App Cliente (Flutter)          📱 App Oficina (Flutter)     │
└────────────┬───────────────────────────────┬─────────────────────┘
             │           HTTP REST           │
             ▼                               ▼
┌──────────────────────────────────────────────────────────────────┐
│  🐳 docker-compose.yml                                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │ autotrix_backend — Flask :5000 — back/                  │     │
│  │                                                         │     │
│  │  /api/clientes  /api/veiculos  /api/servicos            │     │
│  │  /api/disponibilidades  /api/agendamentos               │     │
│  │                                                         │     │
│  │  📤 MOM Publisher → publica eventos AMQP               │     │
│  └────────────────────────┬────────────────────────────────┘     │
│                           │ AMQP                                 │
│  ┌────────────────────────▼────────────────────────────────┐     │
│  │ autotrix_rabbitmq — RabbitMQ :5672 / UI :15672          │     │
│  │                                                         │     │
│  │  Exchange: autotrix.events (topic, durable)             │     │
│  │  ┌─────────────────────────────────────┐                │     │
│  │  │ Filas (durable, persistentes)       │                │     │
│  │  │ q.agendamento.criado                │                │     │
│  │  │ q.agendamento.status                │                │     │
│  │  │ q.negociacao.proposta               │                │     │
│  │  │ q.negociacao.respondida             │                │     │
│  │  └─────────────────────────────────────┘                │     │
│  │  📥 MOM Consumer (Sprint 2)                            |      |
│  └────────────────────────┬────────────────────────────────┘     │
│                           │ psycopg2                             │
│  ┌────────────────────────▼────────────────────────────────┐     │
│  │ autotrix_db — PostgreSQL 16 :5432                       │     │
│  │  clientes · veiculos · servicos                         │     │
│  │  disponibilidades · agendamentos                        │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```
---

## Fluxo de status dos agendamentos

```
                     ┌─────────────┐
                     │   pendente  │
                     └──────┬──────┘
              confirma      │        oficina propõe
              direto ◄──────┤        horário alternativo
                            │ ───────────────────►
                            │                    ┌─────────────┐
                            │                    │ negociacao  │
                            │                    └──────┬──────┘
                            │         aceita ◄──────────┤
                            │                           │ recusa
                            ▼                           ▼
                     ┌─────────────┐           ┌─────────────┐
                     │ confirmado  │           │  cancelado  │
                     └──────┬──────┘           └─────────────┘
                            │
                            ▼
                     ┌─────────────┐
                     │em_andamento │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │  concluido  │
                     └─────────────┘
```
Quando a oficina move o status para `negociacao`, ela obrigatoriamente informa `data_hora_sugerida`. Se o cliente aceitar (`→ confirmado`), o sistema automaticamente promove esse horário como o horário definitivo do agendamento.

---

