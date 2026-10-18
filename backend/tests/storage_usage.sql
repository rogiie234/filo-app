-- Maintained read-only owner query. Run in DEV SQL Editor, not on the phone.
-- Includes empty buckets; metadata size is a snapshot, not billed average usage.
select b.id as bucket_id, count(o.id) as objects,
       coalesce(sum((o.metadata->>'size')::bigint), 0) as bytes,
       round(coalesce(sum((o.metadata->>'size')::bigint), 0)/1048576.0, 2) as mib
from storage.buckets b left join storage.objects o on o.bucket_id = b.id
group by b.id order by b.id;

-- Class paths start class_id/... for materials, submissions and banners.
-- Avatars and any malformed/legacy first segment stay explicitly unassigned.
with objects as (
 select bucket_id, name, coalesce((metadata->>'size')::bigint,0) as bytes,
   case when bucket_id in ('materials','submissions','banners')
     and split_part(name,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     then split_part(name,'/',1)::uuid end as class_id
 from storage.objects
)
select o.class_id, c.course, c.section, o.bucket_id,
       count(*) as objects, sum(o.bytes) as bytes,
       round(sum(o.bytes)/1048576.0,2) as mib
from objects o left join public.classes c on c.id = o.class_id
group by o.class_id,c.course,c.section,o.bucket_id
order by o.class_id nulls last,o.bucket_id;

select count(*) as objects, coalesce(sum((metadata->>'size')::bigint),0) as total_bytes
from storage.objects;
