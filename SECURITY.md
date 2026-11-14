# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately to
the repository owner with the affected version, steps to reproduce and impact.
Do not include real learner or parent data in a report.

## Deployment safety

- Never deploy with `SEED_DEMO_DATA=true`; it creates known demo accounts.
- Keep `.env` out of version control. `.env.example` contains placeholders only.
- Rotate `PB_SUPERUSER_PASSWORD`, SMTP, Twilio and AI provider secrets before launch.
- Use a fresh PocketBase data volume for production.
- Serve the app over HTTPS; the Docker/Caddy setup obtains certificates automatically.
