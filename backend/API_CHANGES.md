# Gradebook backend contracts ? 2026-10-18

Prepared locally; migration deployment, SQL acceptance and dev timings are pending owner execution. The canonical existing RPC reference remains [docs/API_CHANGES.md](../docs/API_CHANGES.md).

## Gradebook query shapes

Use verified instructor requests and RLS; never a service key on the frontend. Load a class once with these four reads, not one request per cell. In the shapes below, CLASS_ID and ASSIGNMENT_IDS are bound values from the selected class. Paginate all results (including submissions and grades) beyond the server row cap; do not silently total partial pages. Refresh after Save/Return; preserve ungraded cells as null/dash rather than zero.

```text
class_members
 select student_id,status,profiles!class_members_student_id_fkey(display_name,avatar_path)
 eq class_id CLASS_ID; in status [active,left,removed]; order student_id
posts
 select id,title,points,due_at,created_at
 eq class_id CLASS_ID; eq kind assignment; is deleted_at null
 order created_at desc,id
submissions
 select id,post_id,student_id,status,submitted_at,is_late
 in post_id ASSIGNMENT_IDS; eq status turned_in; order id
submission_grades
 select submission_id,score,feedback,graded_at,returned_at,
        submissions!inner(post_id,status,posts!inner(class_id,kind,deleted_at))
 eq submissions.posts.class_id CLASS_ID
 eq submissions.posts.kind assignment; is submissions.posts.deleted_at null
 eq submissions.status turned_in; order submission_id
```

Resolve roster profiles with the explicit student foreign key (class_members also references decided_by). Retain former-member rows for historical grades; pending/declined requests are not enrolled roster entries. Student reads remain own returned grades only, with active membership required by existing lifecycle RLS. Never join grade contents into a student cache before Return. An instructor sees turned-in submissions only.

The rollback seed [seed/gradebook_40x10.sql](seed/gradebook_40x10.sql) contains SQL equivalents for measuring all four reads under authenticated owner RLS, including join and policy cost. Expected candidate indexes already exist: idx_members_class, profiles_pkey, idx_posts_class / idx_posts_due, idx_submissions_post and submission_grades_pkey. Inspect EXPLAIN ANALYZE actual plans and Execution Time, target <1,000 ms per query. SQL joins and PostgREST embedding may plan differently: measure frontend-generated queries too when integrated. A sequential scan on 400 rows can be appropriate; do not force index use. No new index is justified without dev measurements. Report all four times and plans before accepting M5-BE-02.

## Grading guard correction

Migration `20261018120000_grading_guards.sql` preserves RPC signatures: `save_grade(p_submission uuid,p_score integer,p_feedback text default null)` returns submission_grades; `return_grades(p_ids uuid[])` and `return_all_graded(p_post uuid)` return actual changed count. Null, negative and above-points scores are refused. Draft/deleted/non-assignment work cannot be saved; Return excludes drafts, unsaved/null scores, previously returned grades, deleted posts and closed classes. Save updates the same primary-key row and preserves returned_at, so edits after Return stay visible without another inbox row. Submission locks serialize Save/Return with unsubmit.

`return_grades` receives submission IDs, not grade IDs or post IDs. IDs belonging to another instructor are ignored. It has no class parameter: an owner supplying IDs across two of their own classes can return both. The frontend must send only selected-class IDs; use return_all_graded(p_post) for assignment scope. Changing this legacy signature requires a separate contract decision.

## Missing-work scoring (M5-SA-01 accepted by owner)

New migration `0011_grade_missing.sql`: `grade_missing(p_post uuid, p_student uuid, p_score integer, p_feedback text default null)` returns `submission_grades`. Verified class owner only; open class, live assignment, server time strictly after due_at, enrolled/former membership (`active`, `left`, `removed`), integer 0..points. Pending/declined/nonmembers and already turned-in work are refused. This is an explicit instructor action, never automatic zero.

Creates a submission or converts a draft to `status=turned_in`, `submitted_at=null`, `unsubmit_until=null`, `is_late=false`, no comment or item metadata. Draft item metadata is discarded to avoid exposing unfinished private contents; SQL does not remove Storage blobs, which remain for class purge. Confirm conversion in the grading UI before calling. Calls save_grade for the same score/feedback rules. Save remains hidden until Return; returned rows count as graded by non-null returned_at, even without submitted_at. Existing policies and turn_in/unsubmit guards lock student changes. Former members retain records for instructor history but cannot see class grades until active membership is restored, per existing lifecycle policy.

On uncertain outcomes, refresh the post/student submission and grade first. Repeating grade_missing after success is refused as already turned in; edit via save_grade using the resulting submission ID. Apply migrations with your existing migration-history workflow: 0011 is deliberately the requested version and sorts before timestamped versions, so existing dev history may require the CLI include-all option. Do not rename or edit applied files. Neither migration has been applied here.
