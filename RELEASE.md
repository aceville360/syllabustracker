# Publishing this repository

This folder is a self-contained source release. It does **not** include local
PocketBase data, `.env`, mailboxes, build output or `node_modules`.

## 1. Create the GitHub repository

```bash
cd syllatrack-github

# create an empty repository on github.com first, then:
git remote add origin https://github.com/YOUR-NAME/YOUR-REPO.git
git push -u origin main
```

The folder is already a Git repository with an initial commit. If you cloned a
different copy, run `git init -b main`, `git add .` and commit instead.

## 2. Choose a licence

`LICENSE` is currently a proprietary placeholder. If you intend an open-source
release, replace it with the licence you want (for example MIT or Apache-2.0)
before publishing.

## 3. Never commit these

- `.env` or any real SMTP/OpenAI/Twilio/PocketBase secret
- `apps/pocketbase/pb_data/` (real school and learner data)
- `.dev-mailbox/`

They are already ignored by `.gitignore`.

## 4. Prototype/demo data

`SEED_DEMO_DATA=false` is the production default and a fresh database contains
no demo school or staff. Set `SEED_DEMO_DATA=true` only for a local demo. The
demo migrations contain known test passwords; never use them on a public server.

## 5. Before a public deployment

Read `docs/production-checklist.md`, configure `.env`, run
`scripts/deploy-preflight.sh` on the VPS, then run:

```bash
node scripts/bug-sweep.mjs https://your-domain/hcgi/api
node scripts/smoke.mjs --base https://your-domain
```

The local production preview is documented in `docs/local-production.md`.
