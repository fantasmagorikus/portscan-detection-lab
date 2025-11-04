# Suricata → Filebeat → Elasticsearch → Kibana (com Juice Shop)

Lab para detectar e visualizar varredura de portas (SYN scan via Nmap) usando Suricata (EVE JSON) → Filebeat (módulo Suricata) → Elasticsearch → Kibana. O OWASP Juice Shop roda como alvo na porta 3000.

**Pré‑requisitos**
- Linux com Docker e Docker Compose
- Dois consoles: identifique (vítima) e (atacante)

**Subir e validar a stack (vítima)**
- `cd homelab-security/suricata-elk-lab`
- `docker compose up -d`
- Verificações rápidas (terminam após imprimir):
  - Elasticsearch: `curl -s http://localhost:9200 | jq .version.number`
  - Kibana: `curl -s http://localhost:5601/api/status | jq .version.number`
  - Filebeat (config): `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test config`
  - Filebeat (output): `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test output`
  - Suricata EVE JSON: `docker exec suricata-lab-suricata sh -lc "ls -lh /var/log/suricata/eve.json; head -n 5 /var/log/suricata/eve.json"`

**Gerar tráfego (atacante)**
- Descobrir IP da vítima (no host vítima): `hostname -I`
- Executar SYN scan: `sudo nmap -sS -p 1-1000 <IP_VITIMA>`

**Kibana – Data View e Lens**
- Data View (vítima): Kibana → Stack Management → Kibana → Data Views → New data view
  - Name: `filebeat-*` | Time field: `@timestamp`
- Filtro KQL base para alerts: `event.module: "suricata" and suricata.eve.event_type: "alert"`
- Timepicker: “Last 5 minutes” ou “Last 15 minutes”

Lens 1) Alerts over time (stacked by signature)
- Visualization type: Area (stacked)
- Vertical axis (Metric): Functions → Count
- Horizontal axis: Field = `@timestamp` → Functions = Date histogram
- Break down by: Field = `suricata.eve.alert.signature` → Functions = Top values → Number of values = 3–5 → Order by = Count of records → Direction = Descending
- Opções do gráfico: habilite “Stacked” (não percentual)
- KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`

Lens 2) Top source IPs (Bar vertical)
- Visualization type: Bar vertical
- Vertical axis: Functions → Count
- Horizontal axis: Field = `source.ip` (ou `suricata.eve.src_ip`) → Functions = Top values
- Ajustes: Number of values = 10 | Order by = Count of records | Direction = Descending

Lens 3) Top destination ports (Bar vertical)
- Vertical axis: Functions → Count
- Horizontal axis: Field = `destination.port` (ou `suricata.eve.dest_port`) → Functions = Top values
- Ajustes: Number of values = 10 | Order by = Count of records | Direction = Descending

Lens 4) Destination port ranges (Bar vertical ou Pie)
- Vertical axis/Metric: Functions → Count
- Horizontal axis/Slice by: Field = `destination.port` (ou `suricata.eve.dest_port`) → Functions = Ranges
- Ranges: 0–1023 | 1024–49151 | 49152–65535

Lens 5) Pie – Top N destination.port
- Metric: Functions → Count
- Slice by: Field = `destination.port` (ou `suricata.eve.dest_port`) → Functions = Top values | Number of values = 3–5
- Habilite porcentagens nas opções do gráfico

Item 6) Tabela de detalhes (recomendado: Discover → Saved search)
- Discover: Kibana → Analytics → Discover
- Data view: `filebeat-*` | KQL: `event.module: "suricata" and suricata.eve.event_type: "alert"`
- Adicione colunas: `@timestamp`, `source.ip`, `source.port`, `destination.ip`, `destination.port`, `network.transport`, `suricata.eve.alert.signature`, `suricata.eve.alert.signature_id`, `suricata.eve.in_iface`
- Ordene por `@timestamp` desc | Save: “Suricata – Alert details (Discover)”
- Em Dashboard: “Edit” → “Add panel” → “Saved search” → selecione a busca salva

**Exportar/Importar objetos do Kibana (UI)**
- Export (UI): Kibana → Stack Management → Saved Objects → Export
  - Pesquise e marque “SIEM LAB NOVO” (Dashboard) e selecione “Include related objects” → Export ndjson
  - Salve em `kibana_exports/export-YYYY-MM-DD-SIEM-LAB-NOVO.ndjson`
- Import (UI): Kibana → Stack Management → Saved Objects → Import → escolha o `.ndjson` → confirme as opções

**Export por API (alternativa automatizada)**
- Encontrar ID: `curl -s -H 'kbn-xsrf: true' 'http://localhost:5601/api/saved_objects/_find?type=dashboard&search_fields=title&search=SIEM%20LAB%20NOVO' | jq -r '.saved_objects[] | select(.attributes.title=="SIEM LAB NOVO") | .id'`
- Exportar: `curl -s -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -X POST 'http://localhost:5601/api/saved_objects/_export' -d '{"objects":[{"type":"dashboard","id":"<ID>"}],"includeReferencesDeep":true}' > kibana_exports/export-$(date +%F)-SIEM-LAB-NOVO.ndjson`

**Backup (script do lab, vítima)**
- `chmod +x scripts/backup.sh && ./scripts/backup.sh`
- Gera `backups/<timestamp>/` com: `compose-ps.txt`, `suricata-logs/` (se existir), `es-snapshot-<SNAP>.json` e `lab-config-<timestamp>.tgz`

Snapshot do Elasticsearch (manual)
- Registrar repo (uma vez):
  - `curl -X PUT http://localhost:9200/_snapshot/lab_repo -H 'Content-Type: application/json' -d '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/snapshots"}}'`
- Criar snapshot agora:
  - `SNAP=snap-$(date +%F-%H%M)`
  - `curl -X PUT "http://localhost:9200/_snapshot/lab_repo/$SNAP?wait_for_completion=true"`
- Restaurar (exemplo):
  - `curl -X POST "http://localhost:9200/_snapshot/lab_repo/$SNAP/_restore" -H 'Content-Type: application/json' -d '{"indices":"filebeat-*","include_global_state":true}'`

**Dicas de leitura e triagem (tabela de detalhes)**
- Clique em valores (ex.: `source.ip`) e use “Filter for value” para refinar
- Campos úteis: `@timestamp`, `source.ip`, `source.port`, `destination.ip`, `destination.port`, `network.transport`, `suricata.eve.alert.signature`, `suricata.eve.alert.signature_id`, `suricata.eve.in_iface`
- Para focar na regra do lab: `suricata.eve.alert.signature_id: 9900001`

**Portfólio (GitHub)**
- `.gitignore` simples (evite versionar `backups/`):
  - ver arquivo `.gitignore` neste projeto
- Comandos (vítima):
  - `git init`
  - `git add . && git commit -m "SOC/SIEM lab: Suricata → Filebeat → ES → Kibana"`
  - `git branch -M main && git remote add origin <URL_DO_SEU_REPO>`
  - `git push -u origin main`
- Inclua no README: arquitetura, passos, KQL, capturas de tela da dashboard, e o arquivo `kibana_exports/*.ndjson`

**Notas**
- Suricata usa `network_mode: host` (Linux). Em macOS/Windows, adapte a captura
- ES sem segurança para simplificar; em produção, habilite `xpack.security` e TLS
