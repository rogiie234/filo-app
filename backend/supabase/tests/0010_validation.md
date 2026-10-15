# Migration 0010 validation

Status: applied and role tests passed on linked DEV, 2026-10-15.

The migration dry run listed only 0010. `db push --linked --include-all --yes`
applied it successfully; a subsequent `migration list --linked` confirmed matching
local/remote 0010 entries. No earlier migration was edited or history repaired.

`db query --linked --file supabase/tests/classmates_and_locked_links.sql` returned
seven PASS rows: active student, non-member, instructor owner, pending member,
notification/deletion/next-day behavior, OTP/privileges, and removed/linkless/deleted
post/class checks. Follow-up query found zero `RPC fixture %` profile rows.
These are real dev database calls under authenticated role with disposable Auth
sessions, not UI login tests. All fixture writes rolled back.

Run `classmates_and_locked_links.sql` as postgres in the DEV SQL Editor after
applying 0010. It creates disposable fixture users/sessions and rolls everything
back. A failing assertion aborts; successful execution returns PASS rows.

Before deployment, inspect linked migration history. 0010 sorts before the
timestamped OTP migrations; use a dry run and verify that only 0010 is pending
before applying with `--include-all`. Do not repair history or apply unrelated
migrations to make this change pass.

Not executed: a two-connection concurrency stress test or a fresh full migration
replay. Concurrent deduplication is enforced by the ledger primary key and
`INSERT ... ON CONFLICT DO NOTHING`, rather than a read-before-write check.

Graphify refresh was attempted but refused publication because existing semantic
fingerprints differ on this backend checkout (README, API/schema/decisions docs,
frontend README/local README/pubspec). The published graph remains stale; source
and live dev SQL, rather than graph absence, were used for verification.
