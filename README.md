# SyllaTrack 

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

The bundled syllabus is the Uganda NCDC  curriculum for Science,
Mathematics, English and Social Studies, three terms per year
(`apps/web/src/lib/curriculumData.js`).

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

