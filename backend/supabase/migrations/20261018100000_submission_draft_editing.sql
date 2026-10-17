-- Persist the draft comment and allow editing the one existing text entry.
-- Submission status/timing/ownership fields remain RPC-only.
begin;

create policy submissions_update_comment on public.submissions
for update to authenticated
using (
  public.current_user_ok()
  and student_id = auth.uid()
  and status = 'draft'
  and public.own_draft_submission(id)
  and exists (select 1 from public.posts p
              where p.id = submissions.post_id and p.deleted_at is null)
  and not exists (select 1 from public.submission_grades g
                  where g.submission_id = submissions.id and g.returned_at is not null)
)
with check (
  public.current_user_ok()
  and student_id = auth.uid()
  and status = 'draft'
  and public.own_draft_submission(id)
  and exists (select 1 from public.posts p
              where p.id = submissions.post_id and p.deleted_at is null)
  and not exists (select 1 from public.submission_grades g
                  where g.submission_id = submissions.id and g.returned_at is not null)
);

grant update (private_comment) on public.submissions to authenticated;
-- Existing items_update policy and trg_item_rules restrict this to own drafts.
-- Existing class lifecycle trigger rejects archived/deleted class writes.
grant update (text_content) on public.submission_items to authenticated;

commit;
