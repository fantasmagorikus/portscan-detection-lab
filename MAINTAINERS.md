# Maintainers — SOC/SIEM Lab (Suricata → Filebeat → ES → Kibana)

Escopo: rege toda a pasta `homelab-security/suricata-elk-lab`.

Objetivo: preservar o contexto do lab e padronizar como os mantenedores devem operar este projeto.

Diretrizes gerais
- Consulte `MAINTAINER_NOTES.md` para estado atual, próximos passos, checklist de Lens, IPs e snapshots.
- Indique explicitamente onde executar cada comando (“(vítima)” ou “(atacante)”).
- Prefira comandos que imprimem e terminam (sem `-f`/follow) salvo solicitação explícita.
- Em Kibana, descreva o caminho completo de navegação (ex.: “Kibana → Stack Management → Kibana → Data Views”).
- Evite `bat/batcat`; prefira `jq`, `less -R`, `lnav`, `multitail`, `rg`.

Backup e persistência
- Use `scripts/backup.sh` para backup automatizado (gera `backups/<timestamp>/` com manifest, snapshot do ES, logs e tar de configs).
- Export de objetos do Kibana é manual (Saved Objects). Salve o `.ndjson` em `kibana_exports/`.
- Quando solicitarem “rodar backup”, execute o script e reporte o caminho final.

Suricata (container)
- Compose usa `network_mode: host` e recebe a interface via `.env` (`SURICATA_IFACE`).
- O container inicia em foreground com `-i ${SURICATA_IFACE:-lo} -c /etc/suricata/suricata.yaml -s /etc/suricata/rules/local.rules`.
- Regras locais: `local-rules/local.rules` (bind RW) carregadas com `-s`.
- Para trocar interface: edite `.env` e recrie apenas o serviço `suricata` (`docker compose up -d --force-recreate --no-deps suricata`).
- Se reiniciar em loop, cheque interface no `.env` e mensagens de permissão/chown; evite capabilities que alterem binds RO (removemos `SYS_NICE`).

Filebeat
- `filebeat.yml` é montado; `strict.perms` desativado (flag + config) para evitar erro de UID.
- Testes úteis (vítima):
  - `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test config`
  - `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test output`

Kibana / Lens
- Data View padrão: `filebeat-*` (Time field: `@timestamp`).
- Ao descrever Lens, cite filtro KQL e campos ECS preferidos (`source.ip`, `destination.port`, `network.transport`). Se faltarem, use `suricata.eve.*` equivalentes.
- Ao concluir cada Lens, sugira export do Saved Objects.

Pausar e retomar
- Ao pausar, registre um checkpoint em `MAINTAINER_NOTES.md` (status dos serviços, último snapshot, próximos passos).
- Ao retomar, leia as notas e confirme serviços; rode `scripts/backup.sh` se necessário.
