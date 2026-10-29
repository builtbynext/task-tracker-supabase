# Meeting Action Tracker

A shared board for actions agreed in meetings. Every action has an owner and a due
date, the board groups them by person, and anything past its due date turns red.
Changes sync live across everyone's screens.

One static HTML page talking directly to Supabase. No build step, no framework,
no dependencies to install.

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

Against a fresh Supabase project, run in the SQL Editor:

1. `supabase/schema.sql` — table, indexes, trigger, RLS policies, realtime.
2. `supabase/seed.sql` — optional sample rows, flagged `is_sample`.

Then update the two constants at the top of the `<script>` block in `index.html`:

```js
var SUPABASE_URL = "https://<your-project>.supabase.co";
var SUPABASE_KEY = "sb_publishable_...";
```

The publishable key belongs in client code — it carries no privileges of its own.
What you can do with it is decided entirely by the RLS policies, which is the next
section and the part that matters.

## Security: read this before sharing the URL

The RLS policies in `schema.sql` grant the `anon` role **full read, write and delete
on every row**. Anyone who opens the deployed page can add actions, tick off someone
else's, or wipe the board. There is no per-user restriction and no audit trail.

That is a reasonable trade for a small team on a URL they keep to themselves. It is
not safe for a public link. This repo is public, so the project URL and key are
discoverable — bots do scan GitHub for exactly this pattern and probe for open tables.

To lock it down, replace the four `to anon, authenticated` policies with
`to authenticated` only, and add Supabase Auth sign-in to the page. A Vercel
Deployment Protection password in front of the site is a cruder but much faster
stopgap.

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

## How the page behaves

- **Writes are optimistic.** The tick flips immediately; if the request fails the
  change reverts and a red banner explains what did not save.
- **Realtime.** A `postgres_changes` subscription merges everyone else's edits as
  they land. The pill next to the filters shows Live / Reconnecting / Offline.
- **Sorting.** Owners with overdue actions float to the top of the grid. Within a
  card, open actions lead by nearest due date and completed ones sink.
- **Dates.** Due dates render as "6 days late" or "Due tomorrow" rather than raw
  dates. A timer re-renders past midnight so an item turns red without a refresh.
- **Per-viewer state.** Only the chosen filter lives in `localStorage`. Everything
  else is shared.
