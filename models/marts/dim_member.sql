-- Member dimension with full history (SCD2) from the snapshot.
-- member_key identifies one *version* of a member; use is_current = true
-- for "member as of today".

with history as (

    select * from {{ ref('snp_members') }}

)

select
    dbt_scd_id                                  as member_key,
    member_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    plan_code,
    zip_code,
    effective_date,
    dbt_valid_from                              as valid_from,
    dbt_valid_to                                as valid_to,
    dbt_valid_to = cast('9999-12-31' as timestamp) as is_current
from history
