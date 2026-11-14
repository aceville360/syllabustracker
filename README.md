# SyllaTrack (Horizons export)

SyllaTrack is a curriculum-coverage tracker for primary schools. Teachers log the
subtopics they actually taught; directors and HODs see, per class and subject,
how far the syllabus has progressed against where the term calendar says it
should be, and which homework or assessments need attention.

This export contains three apps:

| App | Stack | Purpose |
| --- | --- | --- |
| `apps/web` | React 18 + Vite + Tailwind + Radix | The product UI |
| `apps/pocketbase` | PocketBase 0.40 (`pb_migrations`, `pb_hooks`) | Database, auth, rules, seed data |
| `apps/api` | Express 5 | Server-side AI streaming + phone OTP |

The bundled syllabus is the Uganda NCDC P4–P7 curriculum for Science,
Mathematics, English and Social Studies, three terms per year
(`apps/web/src/lib/curriculumData.js`).

## Running it locally

Requirements: Node 22+, npm, and a PocketBase 0.40.x binary for your platform
(the export does not ship the binary).

```bash
# 1. Install dependencies (once)
npm install

# 2. Fetch PocketBase 0.40.4 for macOS arm64 (use your platform's asset otherwise)
mkdir -p .tools
curl -L -o /tmp/pb.zip \
  https://github.com/pocketbase/pocketbase/releases/download/v0.40.4/pocketbase_0.40.4_darwin_arm64.zip
unzip -o /tmp/pb.zip -d .tools

# 3. Start PocketBase + API + Vite together
./scripts/dev.sh
```

Then open <http://127.0.0.1:3000>. The dev server proxies `/hcgi/platform` to
PocketBase (`127.0.0.1:8090`) and `/hcgi/api` to the Express app (`127.0.0.1:3001`),
which is what the Hostinger platform normally does in production.

For a production-mode preview without Docker/Caddy, run:

```bash
npm run build --prefix apps/web
node scripts/serve-production.mjs
```

Open <http://127.0.0.1:4000>. The local proxy mirrors the Caddy routes and
streams AI/realtime responses. See [docs/local-production.md](docs/local-production.md).

`scripts/dev.sh` also starts a local mail sink on `127.0.0.1:1025`. Password
reset links and sign-in codes are written to `.dev-mailbox/` and printed in
`.dev-mailbox.log`, so the full auth flows work without a real mail provider.

### Seeded logins

| Email | Password | Role |
| --- | --- | --- |
| `director@sankara.ug` | `admin123` | Director |
| `science@sankara.ug` | `science1234` | HOD, Science |
| `sarah@sankara.ug` | `sarah1234` | Teacher, P4 Science |

Parent portal demo (separate login at `/parent/login`):

| Email | Password | Linked learner |
| --- | --- | --- |
| `parent@sankara.ug` | `parent1234` | Brian Ssemakula, P4 |

These accounts exist in the current demo database. On a fresh database, set
`SEED_DEMO_DATA=true` before the first PocketBase start to seed the demo school
and accounts; production deployments must keep it `false`, which creates no demo
school or staff. The director account is linked to two schools, so the login
flow shows a workspace picker — a good path to exercise.

### Useful scripts

```bash
node scripts/seed-demo.mjs      # a term of lessons/assessments/homework for the demo school
node scripts/seed-learners.mjs  # roster + per-learner assessment scores and homework submissions
node scripts/seed-attendance.mjs # daily attendance for every class over recent school days
node scripts/backfill-learner-profiles.mjs # fill LIN/sex/date of birth for existing learners
node scripts/seed-academic-mastery.mjs # align the demo year, form teachers and question-level exam scores
node scripts/seed-assessment-weights.mjs # demo categories: BOT/EOT, class assignment and mid-term
node scripts/smoke.mjs          # headless-Chrome walk of every page + screenshots in docs/screenshots
node scripts/dev-mailbox.mjs    # standalone SMTP sink (dev.sh starts one automatically)
scripts/backup.sh               # create a PocketBase backup (production, run on the host)
npm test                        # pure domain + auth/validation unit tests
```

For a fresh database, run `seed-demo.mjs`, `seed-learners.mjs`, then
`seed-attendance.mjs`.
`docs/screenshots/` holds the latest smoke-test captures.

## Sign-in and account recovery

- **Password sign-in** with show/hide, inline validation and friendly error
  messages. Workspace selection still applies to users linked to multiple
  schools.
- **Email sign-in code** — a 6-digit one-time code (5-minute expiry) for users
  who do not want to type a password. The code is requested from the login tab
  and can be resent after a 30-second cooldown.
- **Google SSO** — the button appears automatically when
  `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are set. Without them the provider is
  removed so the UI never offers a broken option.
- **Forgot / reset password** — `/forgot-password` sends a one-time, one-hour
  link; `/reset-password?token=…` enforces the password policy (8+ characters,
  letter and number), shows live rules and confirmation matching, then clears
  stale sessions.
- **Account settings** (`/account`) — profile summary plus a change-password
  form that verifies the current password server-side before updating it.
- **Email verification** — new school accounts must confirm their email before
  they can sign in; the verification link lands on `/verify-email`.
- **Staff management** (`/staff`, director only) — invite teachers and HODs by
  email (they set their own password), edit role/subject/class, resend the
  invite, and deactivate/reactivate accounts without losing their history.

Auth email is configured from environment variables when the `st_users` settings
migration runs:

```bash
APP_URL=https://app.example.com
SMTP_HOST=smtp.example.com SMTP_PORT=587
SMTP_USERNAME=... SMTP_PASSWORD=...
SMTP_FROM_ADDRESS=no-reply@example.com SMTP_FROM_NAME=SyllaTrack
GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=...
```

The migration applies these once. To change them later, update Settings → Mail
settings in the PocketBase admin, or recreate `pb_data` in development. Reset
tokens are one-use/one-hour and OTP codes one-use/five-minute; responses never
reveal whether an account exists.

## Deploying the web app

The repository ships a production container setup: Caddy (TLS + SPA + reverse
proxy), PocketBase (data + auth + mail), and the Express API.

```bash
# On a VPS with Docker + Compose and a DNS A/AAAA record for DOMAIN:
cp .env.example .env
# edit .env: DOMAIN, APP_URL, PB superuser + encryption key, SMTP, optional Google
docker compose up -d --build
```

What happens on first boot:

1. PocketBase applies every migration and creates the superuser from
   `PB_SUPERUSER_EMAIL` / `PB_SUPERUSER_PASSWORD`.
2. The auth migration configures SMTP, `APP_URL`, branded reset/verification
   emails and (if set) Google SSO.
3. Caddy obtains TLS certificates for `DOMAIN` and serves the built SPA.

Important:

- **Set SMTP before the first sign-up.** Verification and invite emails are
  required for onboarding.
- `./pb_data` is the database. Back it up; never delete it in production.
- The PocketBase admin lives at `/_/`; restrict it to your IP or a VPN.
- `scripts/backup.sh` creates an on-box backup under `./pb_data/backups/`; copy
  those off-box with restic/rclone/rsync on a schedule.

Updating:

```bash
git pull
docker compose up -d --build
```

Migrations run automatically. Mail settings from `.env` are applied when the
auth-settings migration first runs; after that, use PocketBase's Settings →
Mail settings (or recreate a fresh `pb_data` in development) if SMTP changes.

### Production checklist

- [ ] DNS points at the VPS; ports 80/443 open; TLS issued
- [ ] Strong `PB_SUPERUSER_PASSWORD` and `PB_ENCRYPTION_KEY`
- [ ] SMTP configured with SPF/DKIM and tested from the login screen
- [ ] `APP_URL` matches the public HTTPS URL exactly
- [ ] `/_/` restricted (firewall/VPN/Cloudflare Access)
- [ ] Daily backups + off-box copy; restore tested once
- [ ] Demo data removed (`pb_data` from development never copied to prod)
- [ ] `GOOGLE_CLIENT_ID`/`SECRET` set only if SSO is wanted
- [ ] Uptime check on `/api/health` and `/hcgi/api/health`
- [ ] Privacy policy / terms pages before public marketing

## What we took from EMIS (and what we left out)

The ministry EMIS manual is a national census-and-compliance system. We borrowed
the parts that make syllabus coverage trustworthy and reproducible, without
turning SyllaTrack into a ministry portal.

**Adopted, adapted to coverage tracking:**

- **Institution identity** – EMIS number, UNEB centre number, ownership, school
  level, phone, address, GPS and founding year live in School Settings →
  Institution and appear on reports.
- **Learner lifecycle** – each learner can carry a LIN, sex, date of birth,
  admission date and an enrollment status (active / transferred / graduated /
  dropped), with exit date and reason. Enrollment reports count active learners
  only, so coverage denominators stay honest.
- **Promotion and graduation** – a director can promote a whole class (or mark
  P7 learners as graduated) at year end. Every move is written to
  `st_promotions` and shown on the learner profile.
- **Teacher deployment** – timetable slots now name the teacher. Timetable and
  Reports show periods per teacher, subjects and classes, so "who should have
  covered this?" has an answer.
- **Termly returns** – a Reports & returns page prints or exports enrollment by
  class and sex, attendance by class, coverage by class/subject, teacher
  workload and assessment averages as CSV.

**Deliberately not copied:**

- ministry account approval, NIN verification and EMIS-number application
- cross-school learner transfers, claims and transition workflows
- finance, budgets, infrastructure, facilities, health/meals, sports and BOG
  registers
- bulk photo uploads, national publications, notices and support ticketing

Those belong to a national EMIS or a district compliance process. Our job is to
help a school see whether the syllabus is actually being taught; the adopted
fields are the minimum needed to make that claim defensible.

The full capability-by-capability mapping is in
[docs/emis-integration.md](docs/emis-integration.md); the mastery model is
documented in [docs/mastery.md](docs/mastery.md). The SchoolPay parent-portal
review and integration recommendation is in
[docs/schoolpay-assessment.md](docs/schoolpay-assessment.md).

## What is wired up

- **Academic period** – one term/week selection in the sidebar, persisted per
  school, backed by `st_academic_calendar` when the school has dates and a
  13-week fallback otherwise. Every progress number uses it.
- **Academic years** – a real `st_academic_years` entity; terms belong to the
  current year, reports name the year, and promotions are recorded against its
  id. School Settings → Calendar can create a year, make it current, and add its
  terms.
- **Academic calendar editor** – School Settings → Calendar edits term names,
  start/end dates and week counts. Saving refreshes the term/week picker and
  every dependent number. Defaults for the current year are one click away.
- **Timetable** – a weekly grid per class (`/timetable`). Directors assign
  subjects, periods and the responsible teacher to each slot; teachers get a
  read-only view and a per-class teacher-load summary. Alerts and pacing use the
  weekly period counts.
- **Curriculum Hub** – per class/subject/term topic tree, subtopic coverage,
  per-topic assessments, manual coverage recalibration, and an import action
  that copies the bundled syllabus into `st_topics` (idempotent; re-runnable).
  Until a school imports, the bundled syllabus is used read-only.
- **Form teachers** – School Settings → Classes assigns a form teacher to each
  class (separate from subject teaching), so the class register has an owner.
- **Students** – roster per class with add/edit/archive, bulk CSV upload with a
  downloadable template, row-level validation, guardian email and duplicate
  skipping, class
  averages, homework completion and at-risk flags. Learners carry a LIN, sex,
  birth/admission dates and an enrollment lifecycle; a student profile shows the
  learner record, promotion history, subject breakdown, attendance, assessment
  history and homework status. Directors can promote or graduate a whole class
  at year end.
- **Attendance** – daily register per class (`/attendance`) with present / late /
  absent / excused, notes, "mark all", previous/next school day navigation and a
  10-school-day rate chart. Attendance rate and history appear on learner
  profiles; the dashboard shows the latest school day's rate; alerts flag
  learners below 80% attendance.
- **Lesson Log, Assessments, Homework** – record what happened. Assessments can
  be entered per learner (or as class totals for schools without a roster) and
  are categorised as class assignment, beginning/mid/end-of-term exam or other.
  Marking homework captures submitted/marked/score per learner and derives the
  class counts. All reads are scoped to the signed-in school, and teachers only
  see their own records.
- **Weighted term assessment** – the final report grade uses the beginning,
  mid and end-of-term exams (normalised exam weights). Weekly homework and class
  assignments are shown separately as progress indicators for teachers and
  parents; they do not change the final grade. Configure the weights in School
  Settings → Assessment. See
  [docs/weighted-assessment.md](docs/weighted-assessment.md).
- **Dashboard** – real lessons/unmarked-homework/low-assessment/behind-class
  counts, coverage by subject, an attention list, at-risk learners and recent
  lessons.
- **Alerts** – timetable-aware missed-lesson and coverage-gap alerts, overdue
  homework, low assessment, at-risk learner, attendance and **mastery-gap**
  alerts. Mastery alerts are grouped by class + subject + topic and list the
  learners below 60%, so a teacher can act on a group rather than one score.
- **Mastery dashboard** (`/mastery`, all roles) – map each exam question to a
  syllabus topic, enter per-learner question scores, and get a class × topic
  heatmap, per-learner topic mastery, intervention groups for every topic below
  60%, and a learner mastery drill-down. Assessments also expose "Map questions"
  directly. Question scores stay linked to the whole-assessment result.
- **Parent portal** (`/parent`) – parent registration/verification, link-child
  requests, school approval, multi-child dashboard with published report cards,
  attendance, announcements, notification inbox and preferences. Report-card
  publication creates an in-portal notification and automatically emails the
  private report-card link to registered parents; announcement emails respect
  the parent preference. See
  [docs/parent-portal.md](docs/parent-portal.md).
- **Announcements** (`/announcements`, director/HOD) – publish school-wide,
  parent-only or class-specific notices that appear in the parent portal.
- **Report cards** (`/report-cards`, all roles) – a printable termly learner report
  with subject grades, overall average, attendance for the term, homework
  completion, topic mastery, conduct and class/head-teacher comments. A period
  picker selects any academic year/term. Teachers can generate a first-draft
  comment from the results or write their own. **Batch print** renders every
  learner in a class as a page-separated pack, and can generate missing comments
  for the whole class. **Publish to portal** stores an immutable snapshot and
  gives a private tokenised parent link (`/portal/report-card/:token`), with
  expiry/renewal, revoke, view tracking and guardian email delivery. Batch
  report cards include **Publish & email class** for report-card day. The full
  workflow and token model are in [docs/report-cards.md](docs/report-cards.md).
- **AI curriculum assistant** – OpenAI-compatible chat for lesson planning,
  homework generation and teaching strategies, with signed image inputs and
  per-teacher history. Configure `OPENAI_API_KEY`, `OPENAI_BASE_URL` and
  `OPENAI_MODEL`; see [docs/ai-assistant.md](docs/ai-assistant.md).
- **Adoption & usage analytics** (`/analytics`, director/HOD) – teacher adoption,
  lesson/assessment/homework activity, class coverage, parent-link adoption,
  report-card portal views and notification delivery. Server-aggregated API;
  see [docs/analytics.md](docs/analytics.md).
- **Reports & returns** (`/reports`, director/HOD) – printable term summary with
  enrollment by class and sex, attendance for the selected term date range
  (falling back to the last 30 school days when historical dates do not overlap),
  syllabus coverage by class/subject with the expected-pace gap, teacher
  workload and assessment averages. Each table exports CSV.

## Publication

Before a public launch, follow [docs/production-checklist.md](docs/production-checklist.md).
The short version: no `.env` is present, Docker has not been exercised here,
SMTP and an OpenAI key must be configured, legal text needs counsel review and
backup/restore must be tested. Fresh databases with `SEED_DEMO_DATA=false` are
clean (no demo school/staff). The local production preview at
`http://127.0.0.1:4000` is suitable for a private pilot, not the public internet.

## Known gaps / next candidates

1. **Mastery capture** – question mapping and per-question scores are entered
   manually; there is no OCR of paper exams or UNEB result import. The 60%
   intervention threshold is fixed in the UI (the settings field exists but is
   not yet exposed). Cross-term mastery trends are not charted.
2. **Historical reporting** – report cards now have a period picker, but the
   Reports & returns page still runs against the current academic year/term.
   Year-over-year comparison is not built.
3. **Parent communications** – parent accounts, portal inbox, announcements and
   SMS/WhatsApp opt-in are in place. Scheduled announcement email, parent↔teacher
   messaging and a configured Twilio sender are not.
4. **Scheduled delivery** – batch publish/email is a manual term action; a
   scheduled report-card-day run is not built.
5. **Billing and plans** – intentionally out of scope while SyllaTrack is a
   syllabus/improvement tool.
6. **Analytics depth** – adoption/usage is live; cross-term trends, retention
   cohorts and per-subject adoption are not built.
7. **Weighted breakdown depth** – the report card shows one weighted score
   across subjects; per-subject weighted breakdowns and category trend charts
   are not built yet.
8. **Roster depth** – bulk CSV upload is validated and templated, but there is
   still no CSV export or photo.
9. **Session revocation** – deactivating staff blocks new sign-ins, but
   PocketBase access tokens issued earlier stay valid until they expire
   (default 14 days). A shorter token lifetime or a token-key rotation is the
   next security hardening step.
10. **Legal review** – Privacy Policy, Terms and Data Processing pages now exist
   and signup requires consent; counsel must review the text and replace the
   placeholder contact addresses before launch.
11. **Container verification** – the Caddyfile is validated, and a container CI
   workflow and `scripts/deploy-preflight.sh` exist. Docker itself is unavailable
   in this environment, so the image build and first boot still need to run on
   the target VPS.
12. **Test coverage** – pure domain, roster, attendance and auth-validation logic
   is unit-tested with `node --test`; write-flow integration tests are still
   manual via `scripts/smoke.mjs` and `scripts/bug-sweep.mjs`.
