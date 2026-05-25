# Relatório de Integração — Middleware Orientado a Mensagens

**Disciplina:** Lab. de Desenvolvimento de Aplicações Móveis e Distribuídas  
**Curso:** Engenharia de Software — PUC Minas  
**Semestre:** 1º Semestre 2026  
**Aluno:** Paloma Dias de Carvalho 
**Professores:** Cleiton Silva Tavares

---

## Contexto

Na Sprint 1, o Autotrix já tinha um backend REST funcional e um banco de dados PostgreSQL rodando em Docker. Tudo funcionava bem para operações síncronas, o cliente fazia uma requisição, o servidor respondia, fim. Mas havia um problema que ficou evidente ao pensar no fluxo real da plataforma: como a oficina saberia, em tempo real, que um novo agendamento chegou? E como o cliente seria avisado quando a oficina confirmasse o horário?

A resposta óbvia seria polling, o app ficaria perguntando ao servidor de tempos em tempos "chegou alguma novidade?". Funciona, mas é ineficiente e não reflete como sistemas distribuídos modernos resolvem esse tipo de problema. Foi aí que entrou o **Middleware Orientado a Mensagens**.

---

## Por que o RabbitMQ?

O **RabbitMQ** se encaixou bem por três razões práticas. Primeiro, implementa o protocolo AMQP, que é um padrão maduro e bem documentado para troca de mensagens entre sistemas. Segundo, oferece diferentes modelos de roteamento que permitem evoluir a arquitetura sem reescrever o código do produtor. Terceiro, vem com uma interface web de administração que facilita muito a visualização e depuração durante o desenvolvimento, acessível em `http://localhost:15672`.

---

## Como o sistema foi organizado

A ideia central foi simples: sempre que algo importante acontece no backend, um evento é publicado. Quem precisar saber sobre aquilo, assina o evento e reage a ele de forma independente.

Para isso, foi criado um **exchange** chamado `autotrix.events`, do tipo **topic**. O exchange funciona como um roteador de mensagens, o produtor não precisa saber quem vai consumir, só precisa dizer o que aconteceu através de uma **routing key**.

O tipo topic foi escolhido porque permite que consumidores se inscrevam em padrões. Por exemplo, se no futuro o sistema tiver um serviço de relatórios, ele pode assinar `agendamento.*` e receber qualquer evento relacionado a agendamentos sem que nenhuma linha do código do produtor precise mudar.

Foram definidas quatro filas, cada uma responsável por um tipo de situação:

**`q.agendamento.criado`** — disparada quando o cliente cria um agendamento. Quem consome é o app da oficina, que precisa saber que chegou uma nova demanda.

**`q.agendamento.status`** — disparada quando o status de um agendamento muda. Quem consome é o app do cliente, que quer saber se o serviço foi confirmado, iniciado ou concluído.

**`q.negociacao.proposta`** — disparada quando a oficina propõe um horário alternativo. O cliente precisa ver essa proposta para aceitar ou recusar.

**`q.negociacao.respondida`** — disparada quando o cliente responde à proposta. A oficina precisa saber se o cliente aceitou ou recusou antes de bloquear o horário na agenda.

---

## O produtor

O produtor foi implementado no arquivo `back/mom/publisher.py`. Toda vez que uma operação relevante acontece nas rotas do Flask, a função `publicar_evento()` é chamada com a routing key correta e o payload do evento.

Uma decisão importante aqui foi garantir que uma falha no RabbitMQ não derrubasse a requisição do usuário. Se o broker estiver temporariamente fora do ar, o erro é registrado em log mas o agendamento continua sendo salvo no banco normalmente. Isso foi uma escolha consciente: preferiu-se consistência eventual a uma falha total da operação.

Todas as mensagens são publicadas com `delivery_mode=2`, que instrui o RabbitMQ a gravar a mensagem em disco antes de confirmar o recebimento. Assim, mesmo que o broker reinicie no meio do caminho, a mensagem não se perde.

---

## O consumidor

O consumidor foi implementado no arquivo `back/mom/consumer.py` e roda como um **serviço completamente separado** no Docker Compose — o container `autotrix_consumer`. Essa separação foi intencional: o consumer não deve competir por recursos com o servidor HTTP, e precisa continuar rodando mesmo que o backend seja reiniciado.

Quando uma mensagem chega, o handler correspondente faz duas coisas:

Primeiro, registra no terminal um log detalhado com todos os campos do evento — quem criou, qual agendamento, qual horário, qual foi a resposta. Isso serve como evidência imediata e visual de que a mensagem foi processada de forma assíncrona, sem qualquer chamada REST direta entre os componentes.

Segundo, salva o evento na tabela `eventos_log` do PostgreSQL, com o payload completo em formato JSONB. Isso cria um histórico auditável que pode ser consultado via `GET /api/eventos/` a qualquer momento.

O consumer usa `prefetch_count=1`, o que significa que ele processa uma mensagem por vez e só solicita a próxima após confirmar (via ACK) que terminou de processar a anterior. Isso evita sobrecarga e garante que mensagens não fiquem presas em caso de falha no meio do processamento.

---

## Desafios encontrados

Nem tudo saiu como planejado na primeira tentativa. Três problemas apareceram durante o desenvolvimento que merecem registro.

O primeiro foi com a serialização de tipos do PostgreSQL. Os campos `TIME` e `DATE` são retornados pelo psycopg2 como objetos Python nativos que o Flask não consegue converter para JSON automaticamente. A solução foi fazer o cast diretamente no SQL com `hora_inicio::text`, evitando qualquer conversão no lado da aplicação.

O segundo foi a questão das filas. O RabbitMQ não cria filas automaticamente quando um produtor publica em uma routing key sem binding correspondente, as filas precisam ser declaradas explicitamente. O consumer já faz isso ao iniciar, mas nas primeiras execuções o consumer ainda não estava rodando quando o producer tentou publicar. A solução foi inicializar a infraestrutura manualmente via script antes do primeiro teste.

O terceiro foi um cache corrompido do Docker que impediu o rebuild da imagem. Após `docker system prune -af`, o problema foi resolvido e os containers subiram normalmente.

---

## Resultado

Ao final da Sprint 2, o fluxo completo de comunicação assíncrona está funcionando: o cliente cria um agendamento pelo Postman, o backend publica o evento no RabbitMQ sem saber quem vai consumir, e o consumer — rodando em processo completamente separado — processa a mensagem, exibe o log e salva no banco. A evidência pode ser verificada tanto no terminal do Docker quanto na API de eventos em `GET /api/eventos/`.

Na Sprint 3, esses handlers serão conectados ao mecanismo de notificação push dos aplicativos Flutter, transformando os logs em notificações reais para os usuários.

---

## Referências

HOHPE, Gregor; WOOLF, Bobby. *Enterprise Integration Patterns: designing, building, and deploying messaging solutions*. Boston: Addison-Wesley, 2003.

RICHARDSON, Chris. *Microservices patterns: with examples in Java*. Shelter Island: Manning, 2018.

COULOURIS, George et al. *Distributed Systems: concepts and design*. 5th ed. Boston: Addison-Wesley, 2011.