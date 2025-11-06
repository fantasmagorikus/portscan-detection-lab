# Contributing

Thanks for your interest in improving this lab! This project showcases a Suricata → Filebeat → Elasticsearch → Kibana pipeline for detecting TCP SYN port scans.

Ways to contribute
- Documentation: clarify setup, add troubleshooting, expand KQL examples
- Reproducibility: improve Saved Objects (NDJSON) or add sample data
- Detection: propose additional Suricata rules or tuning parameters
- Scripts: small helpers for health checks, exports, or backups

Getting started
1) Fork the repo and create a feature branch from `main`
2) Make focused changes with clear commit messages
3) Open a Pull Request describing the change and how to validate it

Coding and docs conventions
- Keep changes minimal and focused; avoid unrelated edits
- Prefer English-first documentation (Portuguese translation welcome)
- Include commands that print and exit (avoid tail -f) for reproducible checks
- Follow SemVer in CHANGELOG entries when relevant

Reporting issues
- When possible, include environment info (OS, Docker versions) and copy/pasteable commands
- Attach logs or screenshots that demonstrate the problem

License
- Contributions are licensed under the terms of the MIT License

