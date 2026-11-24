-- Every member must have exactly one current version in dim_member.

select
    member_id,
    sum(case when is_current then 1 else 0 end) as current_versions
from {{ ref('dim_member') }}
group by member_id
having sum(case when is_current then 1 else 0 end) <> 1
