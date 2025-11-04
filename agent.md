# Lab: Suricata → Filebeat → Elasticsearch → Kibana

Objetivo: detectar e visualizar varredura de portas (SYN sweep via Nmap) usando Suricata gerando EVE JSON, Filebeat (módulo Suricata) enviando para Elasticsearch, com visualização no Kibana. Inclui persistência de dados e backup por snapshot.

Arquitetura (Docker):
- suricata (network_mode: host) captura tráfego via `pcap` em `any` e grava `/var/log/suricata/eve.json`.
- filebeat (módulo suricata) lê `eve.json` e envia para `Elasticsearch`.
- elasticsearch (single-node, segurança desativada para simplificar) com volumes persistentes e `path.repo` para snapshots.
- kibana conectado ao Elasticsearch para exploração/visualização.

Persistência:
- Volumes nomeados: `es-data`, `es-snapshots`, `kibana-data`, `filebeat-data`, `suricata-logs`.
- `es-snapshots` é montado em `/usr/share/elasticsearch/snapshots` e já está no `path.repo`.

Backup (snapshot):
1) Registre o repositório de snapshots em `/_snapshot/lab_repo` (ver README).
2) Crie snapshots sob demanda (ex.: `snap-YYYYMMDDHHMMSS`).
3) Para restaurar, use a API `_restore` apontando para o snapshot desejado.

Detecção (lógica):
- A detecção de varredura de portas (SYN sweep) será feita no SIEM (Kibana) agrupando conexões TCP por `source.ip` e contando a quantidade de portas de destino distintas em uma janela curta (ex.: 1–5 min). Um valor alto indica varredura.
- Opcional: filtrar por tentativas que não estabelecem sessão (SYN sem ACK), quando os campos de flags estiverem disponíveis via Suricata (ex.: incluir apenas `flow` TCP de curta duração ou com flags contendo `S` e não `A`).

Visualização sugerida:
- Data View: `filebeat-*` (cobre os índices do Filebeat com `event.module: suricata`).
- Lens (barra ou tabela):
  - Break down: `Top values of source.ip` (Top N).
  - Metric: `Unique count of destination.port`.
  - Filtro KQL: `event.module: "suricata" and suricata.eve.event_type: "flow" and network.transport: "tcp"`.
  - Janela temporal: 1m a 5m. Valores elevados sugerem scan.

Geração de tráfego (Nmap):
- Ex.: `sudo nmap -sS -p 1-1000 127.0.0.1` ou apontando para outro host/container alcançável.
- Em Linux, `-sS` exige privilégios (use `sudo`).

Notas de sistema:
- O serviço `suricata` usa `network_mode: host` (suportado apenas no Docker em Linux). Em macOS/Windows (Docker Desktop), considere rodar o Suricata no host ou adaptar a captura para uma interface específica.
- Segurança do Elasticsearch está desativada para simplificação do lab. Em produção, habilite `xpack.security` e TLS.

Extensões futuras (ideias rápidas):
- Adicionar regra de alerta por port-scan no próprio Suricata (via regras ET/Open ou lógica customizada) para gerar `alert` além de `flow`.
- Habilitar detecção no Security Solution (Kibana) com regra de threshold/ES|QL quando `xpack.security` estiver habilitado.
- Exportar visualizações/dashboards como NDJSON e versionar em `exports/`.

---

Estado atual (checkpoint)
- IP da Vítima: 192.168.0.145
- Stack Docker criada em `homelab-security/suricata-elk-lab`:
  - Elasticsearch/Kibana/Suricata/Filebeat/Juice Shop definidos em `docker-compose.yml`.
  - Filebeat com `strict.perms: false` no `filebeat.yml` e também `-strict.perms=false` no comando do serviço (para evitar erro de permissões ao montar config do host).
- Próximo passo: verificar que o Filebeat está “running” e enviando eventos para o Elasticsearch; criar Data View `filebeat-*` e executar Nmap (SYN sweep) a partir do atacante.

Ferramentas instaladas no host (para leitura de logs)
- lnav, multitail, jq, ripgrep (rg), fzf, bat(batcat), ccze, grc
- Objetivo: facilitar leitura de logs e JSON (EVE) no terminal durante o lab.

Nota de preferência do usuário
- Evitar uso do `bat/batcat` (causou travamento). Preferir `rg`, `jq`, `less`, `lnav`, `multitail`.

Próximos passos (to‑do)
1) Verificar status do Filebeat (Docker) e saída para ES.
2) Confirmar que Suricata escreve `/var/log/suricata/eve.json`.
3) Criar Data View `filebeat-*` no Kibana.
4) Executar `nmap -sS` do atacante contra 192.168.0.145 (varredura 1–1000).
5) Visualizar no Kibana (Lens: unique ports por source.ip, janela 1–5 min).
6) Fazer snapshot do Elasticsearch e backup do diretório do lab.

---

Lens desejadas (para dashboard Port Scanning / Suricata)
- 1) Alerts over time (stacked by signature)
  - KQL (ECS+module): `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - X: `@timestamp` (Date histogram). Y: Count. Breakdown: Top values `suricata.eve.alert.signature` (3–5). Stacked.
  - Variante: focar na regra local `sid: 9900001`: adicionar `suricata.eve.alert.signature_id: 9900001`.
- 2) Top source IPs (quem varre)
  - KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - Bar horizontal: Y: Top values `source.ip` (size 10). X: Count. Ordenar por Count desc.
- 3) Top destination ports (portas mais visadas)
  - KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - Bar vertical: X: Top values `destination.port` (size 10). Y: Count.
- 4) Dest port ranges (Well‑Known/Registered/Dynamic)
  - KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - Bar vertical (ou Pie): Ranges personalizados sobre `destination.port`: 0–1023, 1024–49151, 49152–65535. Métrica: Count.
- 5) Pie – Top N destination.port
  - KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - Pie/Donut: Slices = Top values `destination.port` (N=3 ou 5). Rank: Count desc. Mostrar %.
- 6) Tabela de detalhes (triagem)
  - KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
  - Colunas: `@timestamp`, `source.ip`, `source.port`, `destination.ip`, `destination.port`, `network.transport`, `suricata.eve.alert.signature`, `suricata.eve.alert.signature_id`, `suricata.eve.in_iface`. Ordenar `@timestamp` desc.

Notas de campos
- Preferir ECS: `source.ip`, `destination.port`, `network.transport`. Em alguns dados você também verá `suricata.eve.src_ip`, `suricata.eve.dest_port` — use se os ECS não aparecerem.

Checklist de Lens (status)
- [x] 1) Alerts over time (stacked by signature)
- [x] 2) Top source IPs
- [x] 3) Top destination ports
- [x] 4) Dest port ranges
- [x] 5) Pie – Top N destination.port
- [x] 6) Tabela de detalhes (Discover Saved Search)

---

Preferências de instrução (guardar para próximas sessões)
- Sempre indicar em qual console executar: (vítima) ou (atacante).
- Em Kibana, descrever caminho de navegação com clareza. Ex.: “Kibana → Stack Management → Kibana → Data Views”.
- Usar apenas comandos que imprimem e terminam (evitar follows infinitos) quando checando estado.
- Evitar `bat/batcat` (preferir `jq`, `less`, `lnav`, `multitail`, `rg` quando necessário).
- Usuário autorizou pesquisa online sempre que necessário para instruções melhores (Elastic 8.8 e Suricata/Filebeat).

---

Checkpoint de sessão (progresso salvo)
- Suricata estável na interface definida em `.env` (`SURICATA_IFACE`).
- Regra local carregada: `local-rules/local.rules` (sid: 9900001 - LAB TCP SYN).
- Filebeat OK e conectado ao Elasticsearch 8.14.3; módulo Suricata ativo.
- Kibana Data View: `filebeat-*` (Time field: `@timestamp`).
- Dashboard concluída: SIEM LAB NOVO (Lens 1–5) + tabela de detalhes via Discover (Saved search).
- Dica: filtro KQL base das Lens: `event.module: "suricata" and suricata.eve.event_type: "alert"`.

Backups (auto) – status
- Script `scripts/backup.sh` testado (CLI): concluiu com sucesso.
- Último backup gerado: backups/2025-11-04-155930 (ver manifest e tar.gz)
- Observação: na CLI sem Docker/ES locais, etapas de logs/snapshot podem ser marcadas como "skipped"; no host da vítima, ambas executam normalmente.

Backup rápido (procedimento)
- Console (vítima): backup das configs do lab
  - `cd /home/ghost && tar czf soc-siem-lab-$(date +%F-%H%M).tgz homelab-security/suricata-elk-lab`
- Console (vítima): copiar logs do Suricata
  - `mkdir -p /home/ghost/homelab-security/suricata-elk-lab/backups`
  - `docker cp suricata-lab-suricata:/var/log/suricata /home/ghost/homelab-security/suricata-elk-lab/backups/suricata-logs-$(date +%F-%H%M)`
- Console (vítima): snapshot do Elasticsearch (idempotente)
  - Registrar repositório (uma vez):
    - `curl -X PUT http://localhost:9200/_snapshot/lab_repo -H 'Content-Type: application/json' -d '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/snapshots"}}'`
  - Criar snapshot agora:
    - `SNAP=snap-$(date +%F-%H%M)`
    - `curl -X PUT "http://localhost:9200/_snapshot/lab_repo/$SNAP?wait_for_completion=true"`
  - Verificar snapshots:
    - `curl -s http://localhost:9200/_cat/snapshots/lab_repo?v`
- Kibana (UI): exportar Saved Objects (.ndjson)
  - Kibana → Stack Management → Saved Objects → Export
  - Em “Select objects to export”, pesquise e marque: “SIEM LAB NOVO” (Dashboard) e marque “Include related objects” para incluir Lens dependentes.
  - Clique “Export ndjson” e salve como `homelab-security/suricata-elk-lab/kibana_exports/export-$(date +%F)-SIEM-LAB-NOVO.ndjson`.

Kibana (API) – exportar Dashboard “SIEM LAB NOVO” (alternativa automatizada)
- Console (vítima):
  - `curl -s -H 'kbn-xsrf: true' 'http://localhost:5601/api/saved_objects/_find?type=dashboard&search_fields=title&search=SIEM%20LAB%20NOVO' | jq -r '.saved_objects[] | select(.attributes.title=="SIEM LAB NOVO") | .id'`
  - Exporte por ID: `curl -s -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -X POST 'http://localhost:5601/api/saved_objects/_export' -d '{"objects":[{"type":"dashboard","id":"<ID>"}],"includeReferencesDeep":true}' > homelab-security/suricata-elk-lab/kibana_exports/export-$(date +%F)-SIEM-LAB-NOVO.ndjson`

Notas – Tabela de detalhes (triagem) e leitura
- Use Saved Search (Discover) para eventos brutos: `filebeat-*` + KQL de alertas.
- Campos úteis: `@timestamp`, `source.ip`, `source.port`, `destination.ip`, `destination.port`, `network.transport`, `suricata.eve.alert.signature`, `suricata.eve.alert.signature_id`, `suricata.eve.in_iface`.
- Clique em valores (ex.: `source.ip`) para aplicar filtros rápidos (“Filter for value”).
- Para focar na regra local do lab: adicione `suricata.eve.alert.signature_id: 9900001` ao KQL.

Próximos passos (quando retomar)
- Git/Portfólio: versionar o lab no GitHub (README com arquitetura, passos de execução, capturas da dashboard, e NDJSON exportado em `kibana_exports/`).
- Documentar: inclua pré‑requisitos, como subir a stack, gerar tráfego (nmap), e navegar no Kibana para as Lens.
- Exportar novamente os Saved Objects após cada sessão.

Lembrete da próxima sessão (ao invocar o agente e/ou pedir “rodar backup agora”)
- (vítima) Executar `scripts/backup.sh` e registrar o caminho final do backup.
- Abrir Kibana → Analytics → Dashboard → “SIEM LAB NOVO” e VISUALIZAR a Lens 1 (Alerts over time – stacked by signature) para validar se há alertas recentes.
- Revisar documentação: confirmar que o README contém instruções da Lens 1 (Date histogram em `@timestamp`, Breakdown por `suricata.eve.alert.signature`, KQL de alertas). Se faltar, atualizar.
- Exportar Saved Objects novamente (UI ou API) e salvar em `kibana_exports/` com a data do dia.
- Atualizar este `agent.md` em “Checkpoint de sessão” com: status, último snapshot/backup e próximos passos.
