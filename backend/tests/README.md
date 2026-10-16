# Join and approval dev SQL guide

Status: owner reported all 92 checks PASS on 2026-10-16; the assistant did not run tests. Run only on development project `fiobwfzmqcffbpixzvbq`.

1. Open that project's Supabase dashboard, then SQL Editor. Confirm the project reference and select the `postgres` role.
2. Confirm the dev database has the repository migrations, including `20261014160000_verified_session_gate.sql`. This script does not deploy or change functions.
3. Paste the entire `backend/tests/class_join_approval.sql` file into a new query and Run once. Keep BEGIN through ROLLBACK together. No IDs, Google accounts, JWTs or secrets need to be supplied.
4. Success means the entire query completes without any error and every returned result is PASS. The results include all nine requested scenarios, membership checks, notification payload/count checks, and inbox isolation. The final bulk state expects nine notifications: four instructor requests, four notifications for student 2 (two approvals, one decline, one removal), and one approval for student 3.
5. Send the PASS output or the first error with its context and your run date. Earlier PASS rows do not override a later error. If your session remains in an aborted transaction, run `ROLLBACK;` before rerunning the whole script.

Disposable Auth users, Auth sessions, verified sessions, profiles, class, memberships, notifications and temporary helpers are created in one transaction and rolled back. No fixture data should remain. RPCs run as authenticated users; postgres is used only for fixture setup and complete-effect assertions. Any external webhook side effects depend on dev configuration and are outside database rollback guarantees.

This verifies database behavior and RLS inbox visibility. It does not prove OTP login, app screens, push delivery or concurrent requests. The first owner-reported dev run passed all 92 checks; retain this guide for reruns. If a bug is found, add a new migration and rerun this script rather than editing an old migration.
