# Optional account & sync (P5)

FluentMusic works **100% without an account**. Sign-in exists for one reason:
carrying playlists and the song library between devices. Nothing is ever gated
behind it, and every screen stays usable in guest mode.

---

## 1. What syncs, what never leaves the phone

| Synced (library data) | Never uploaded |
|---|---|
| `likedSongs` | audio files / downloads |
| `recentlyPlayedSongs` | playback settings, equalizer, theme |
| `customPlaylists` (user-created) | account tokens (stay in local Hive) |
| `likedPlaylists` (liked albums / artists) | search history |
| `playlists` (saved YouTube playlist IDs) | listening stats |
| `playlistFolders` | cache |
| `pinnedPlaylistIds` | |
| `likedRadioStations` | |

Merge rule for v1.4.0: **union by id**. Local wins on conflicts, remote-only
items are added. Deletions are intentionally **not** propagated — a phone that
is offline for a week can never erase another device's library. A future version
can add tombstones; v1.4.0 stays safe and boring.

Layout in the cloud: **one row per user**, a JSON snapshot. No per-song rows, no
schema migrations every release.

```
user_sync
  user_id    uuid  primary key references auth.users(id) on delete cascade
  payload    jsonb not null
  updated_at timestamptz not null default now()
```

---

## 2. Build-time configuration (optional)

There are **no keys committed to the repo**. To enable cloud sync in a build:

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

* Missing keys → app prints "Cloud sync is not configured in this build" in
  Account and hides email/password fields. Local profile + JSON export remain.
* The anon key is designed to be public; **Row Level Security** is what protects
  data. Never put the `service_role` key in the app.

---

## 3. Supabase setup (copy-paste)

Run once in the SQL editor:

```sql
-- 1. Table
create table if not exists public.user_sync (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

-- 2. Row Level Security
alter table public.user_sync enable row level security;

drop policy if exists "read own sync" on public.user_sync;
create policy "read own sync"
  on public.user_sync for select
  using (auth.uid() = user_id);

drop policy if exists "insert own sync" on public.user_sync;
create policy "insert own sync"
  on public.user_sync for insert
  with check (auth.uid() = user_id);

drop policy if exists "update own sync" on public.user_sync;
create policy "update own sync"
  on public.user_sync for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. Keep updated_at honest
create or replace function public.touch_user_sync()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists user_sync_touch on public.user_sync;
create trigger user_sync_touch
  before update on public.user_sync
  for each row execute function public.touch_user_sync();
```

Auth settings to check in the dashboard:

* **Authentication → Providers → Email**: enabled.
* For quick testing, disable "Confirm email". With confirmation on, sign-up
  returns no session and the app honestly says "Check your email, then sign in".
* No password-reset flow ships in 1.4.0. Use the Supabase dashboard if a user
  forgets a password. This is documented, not hidden.

The app talks to Supabase over plain REST (`/auth/v1`, `/rest/v1`). There is no
`supabase_flutter` dependency, no native SDK, and no background service.

---

## 4. Two-device test script

1. Build with keys, install on **phone A** and **phone B**.
2. Phone A: Settings → Account → create account / sign in.
3. Phone A: like 3 songs, create a playlist "Roadtrip", add 2 songs, pin it.
4. Phone A: Account → **Sync now** → toast "Library synced".
5. Phone B: install, sign in with the same account.
6. Phone B: Account → **Sync now** → all 3 liked songs, "Roadtrip" and pin state
   appear. Playback still uses phone B's own downloads.
7. Airplane mode on B, like a song, Sync now → "Sync timed out · will retry
   later"; `syncPending` is stored and auto-sync retries next launch.
8. Sign out on B: library stays (it is local), tokens are removed, auto-sync
   stops. Sign back in to resume.

Expected console/API side-effects:

* `GET /rest/v1/user_sync?user_id=eq.<uuid>&select=payload` → 200, 0 or 1 row.
* `POST /rest/v1/user_sync` with `Prefer: resolution=merge-duplicates` → 201.

---

## 5. No-account fallback (always available)

Settings → Account → **DATA & BACKUP**:

* **Export library JSON** — portable snapshot (same payload as cloud sync) via
  the system file picker.
* **Import library JSON** — merges that snapshot back (union by id).
* **Full app backup / restore** — the existing Hive-file backup for `user` and
  `settings`. Restart the app after restoring.

This path needs zero network and zero account, which is the point.

---

## 6. Honest limitations (v1.4.0)

* Union merge means **unliking / deleting does not propagate** between devices.
* No realtime: sync happens on launch (auto-sync toggle) or when tapping
  **Sync now**.
* No in-app password reset, email change, or account deletion. Dashboard only.
* Listening stats and settings are per-device by design.
* Cloud sync is a convenience, not a backup guarantee. Export JSON for real
  backups.
