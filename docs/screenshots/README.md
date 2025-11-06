Screenshots
===========

This folder contains real screenshots captured from Kibana using `scripts/capture_screenshots.sh`.

Included images
- `dashboard_overview.png` — Dashboard “Port Scan Detection (Suricata)”, time range: last 1 hour
- `dashboard_overview_last5.png` — Same dashboard, time range: last 10 minutes
- `top_sources.png` — Lens: “Suricata – Top source IPs (alerts)” (embed view)
- `top_ports_closeup.png` — Dashboard viewport tuned to focus on Top destination ports panel
- `discover_alerts.png` — Discover saved search: “Suricata – Alert details (Discover)”

How to regenerate
- Ensure recent alerts exist (run an Nmap SYN scan or generate outbound connections):
  - `make nmap-local` (single-host) or generate multiple HTTP(S) requests
- Run: `make screenshots`
- The script retries until alerts are present and then captures all views in kiosk/embed mode.
