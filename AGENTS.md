# AGENTS.md — SOC/SIEM Lab (Suricata → Filebeat → ES → Kibana)

Escopo: este arquivo rege toda a pasta `homelab-security/suricata-elk-lab`.

Objetivo: preservar o contexto do lab e padronizar como o assistente deve interagir, orientar e operar neste projeto para que o usuário possa pausar e retomar sem perder nada.

Instruções de interação
- Sempre consultar `agent.md` (raiz do lab) ao iniciar ou retomar: estado atual, próximos passos, checklist de Lens, IPs, snapshots, preferências.
- Sempre indicar explicitamente onde executar cada comando: “(vítima)” ou “(atacante)”.
- Preferir comandos que imprimem e terminam (sem `-f`/follow). Use follow apenas se o usuário pedir.
- Em Kibana, informar o caminho de navegação completo (ex.: “Kibana → Stack Management → Kibana → Data Views”).
- Evitar `bat/batcat`; preferir `jq`, `less -R`, `lnav`, `multitail`, `rg` quando necessário.
- O usuário autorizou pesquisa online; pode pesquisar para melhorar instruções (Elastic 8.8, Suricata, Filebeat, Kibana Lens).

Backup e persistência
- Usar `scripts/backup.sh` para backup automatizado (gera pasta em `backups/<timestamp>/` com manifest, snapshot do ES, logs do Suricata e tar das configs essenciais).
- Export de objetos do Kibana é manual pelo usuário (Saved Objects). Orientar a salvar o `.ndjson` em `kibana_exports/`.
- Ao usuário pedir “rodar backup agora”, executar o script e reportar o caminho final.

Suricata (container)
- Compose usa `network_mode: host` e define a interface via variável `SURICATA_IFACE` em `.env`.
- O serviço Suricata é iniciado em foreground (sem `-D`). O comando do container já inclui `-i ${SURICATA_IFACE:-lo} -c /etc/suricata/suricata.yaml -s /etc/suricata/rules/local.rules`.
- Regras locais ficam em `local-rules/local.rules` (montado RW) e são carregadas com `-s`.
- Para trocar a interface, editar `.env` e recriar apenas o serviço: `docker compose up -d --force-recreate --no-deps suricata` (vítima).
- Se o container reiniciar em loop, verificar: (1) interface correta no `.env`, (2) mensagens de permissão/chown; evitar capabilities que forcem chown em bind mounts RO. Nesta stack `SYS_NICE` foi removido para evitar fix_perms.

Filebeat
- `filebeat.yml` está montado; `strict.perms` desabilitado por flag e config para evitar erro de UID em bind mount.
- Testes úteis (vítima):
  - `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test config`
  - `docker exec -it suricata-lab-filebeat filebeat -e -strict.perms=false test output`

Kibana / Lens
- Data View padrão: `filebeat-*` (Time field: `@timestamp`).
- Nas instruções de criação de Lens, sempre indicar filtro KQL e campos ECS preferenciais (`source.ip`, `destination.port`, `network.transport`). Caso não existam, usar `suricata.eve.*` equivalentes.
- Ao concluir cada Lens, marcar o checklist no `agent.md` e sugerir export do Saved Objects.

Pausar e retomar
- Ao pausar: atualizar `agent.md` com “Checkpoint de sessão”: o que foi feito, status dos serviços, último snapshot e próximos passos.
- Ao retomar: ler `agent.md` e continuar do checklist; confirmar serviços e, se necessário, rodar `scripts/backup.sh` antes de avançar.

