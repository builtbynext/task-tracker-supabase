# Meeting Action Tracker

A shared board for actions agreed in meetings. Every action has an owner and a due
date, the board groups them by person, and anything past its due date turns red.
Changes sync live across everyone's screens, and nothing is visible until you sign in.

One static HTML page talking directly to Supabase. No build step, no framework,
no dependencies to install.

## Signing in

Sign-in takes a **username**, not an email address. Supabase Auth is an
email/password system underneath, so the page appends a fixed domain to whatever
you type — `priya` becomes `priya@example.com`. That domain lives in one place,
`EMAIL_DOMAIN` at the top of the script in `index.html`, and must match the domain
the accounts were created under.

Seeded accounts:

| Username | Display name |
| --- | --- |
| `priya` | Priya |
| `dan` | Dan |
| `marcus` | Marcus |

All three start on the password `password`. **Change this.** See the security
section below.

## Deploying to Vercel

1. In Vercel, **Add New → Project** and import `builtbynext/task-tracker-supabase`.
2. Framework preset: **Other**. Leave the build command and output directory empty —
   `index.html` sits at the repo root and is served as-is.
3. Deploy.

`vercel.json` sets cache and security headers. Its `Content-Security-Policy` pins
`connect-src` to the Supabase project below, so **if you point the app at a different
Supabase project you must update that header too**, or the browser will block the
connection.

## Setting up the database

Against a fresh Supabase project, run these in the SQL Editor in order:

1. `supabase/schema.sql` — tables, indexes, triggers, RLS policies, realtime.
2. `supabase/users.sql` — creates the three sign-in accounts.
3. `supabase/seed.sql` — optional sample actions, flagged `is_sample`.

Then update the constants at the top of the `<script>` block in `index.html`:

```js
var SUPABASE_URL = "https://<your-project>.supabase.co";
var SUPABASE_KEY = "sb_publishable_...";
var EMAIL_DOMAIN = "example.com";
```

The publishable key belongs in client code — it carries no privileges of its own.
What you can do with it is decided entirely by the RLS policies.

## Security

**Access.** Both tables are closed to the `anon` role. Holding the publishable key
alone gets you nothing; every read and write requires a session. Any signed-in user
can read and edit every action, which is the point of a shared team board — there is
no per-user ownership of rows and no audit trail of who changed what.

**The shared starting password is the weak link.** All three accounts begin on
`password`, this repo is public, and the deployed URL is public. Anyone who finds
both can sign in as any of your team. Options, roughly in order of effort:

- Reset each password to something real (the `update` snippet at the bottom of
  `supabase/users.sql`).
- Turn on **leaked password protection** in Supabase → Authentication → Policies,
  which rejects known-compromised passwords like this one outright.
- Add **Vercel Deployment Protection** so the site itself needs a password too.
- Add a forced password change on first sign-in. Not built yet.

**About `users.sql`.** It inserts directly into `auth.users`, a Supabase-managed
schema. That is fine for seeding a few accounts from the SQL Editor, but the Admin
API (`supabase.auth.admin.createUser()`, service role key, server-side only) is the
supported path and will not break under an auth upgrade.

## Data model

`public.meeting_actions`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key, generated |
| `title` | `text` | What was agreed. Non-empty |
| `owner_name` | `text` | Who owns it. Non-empty; the board groups on this |
| `due_on` | `date` | Nullable — an action can sit undated |
| `meeting` | `text` | Which meeting it came from. Nullable |
| `done` | `boolean` | Defaults false |
| `done_on` | `date` | Set when ticked, cleared when un-ticked |
| `agreed_on` | `date` | Defaults to the day the row was created |
| `is_sample` | `boolean` | Drives the "clear sample actions" banner |
| `created_at` / `updated_at` | `timestamptz` | `updated_at` maintained by trigger |

`public.profiles` — one row per auth user, created automatically by the
`on_auth_user_created` trigger.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key, FK to `auth.users`, cascades on delete |
| `username` | `text` | Unique, lowercase, what you type at sign-in |
| `display_name` | `text` | Shown on the board |
| `created_at` | `timestamptz` | |

`owner_name` on an action is free text rather than a foreign key to `profiles`, so
you can assign work to someone who has no login yet. The owner field autocompletes
from both existing owners and the profile list.

## How the page behaves

- **Sessions persist.** Signing in survives a reload and a closed tab; the token
  refreshes itself. Sign out clears it and drops the realtime subscription.
- **Writes are optimistic.** The tick flips immediately; if the request fails the
  change reverts and a red banner explains what did not save.
- **Realtime.** A `postgres_changes` subscription merges everyone else's edits as
  they land. The pill next to the filters shows Live / Reconnecting / Offline.
- **Sorting.** Owners with overdue actions float to the top of the grid. Within a
  card, open actions lead by nearest due date and completed ones sink. Your own card
  is marked and carries the accent colour.
- **Filters.** All, Open, Overdue, Mine, Done. "Mine" matches your display name or
  username against the owner field.
- **Dates.** Due dates render as "6 days late" or "Due tomorrow" rather than raw
  dates. A timer re-renders past midnight so an item turns red without a refresh.
- **Per-viewer state.** Only the chosen filter lives in `localStorage`. Everything
  else is shared.
