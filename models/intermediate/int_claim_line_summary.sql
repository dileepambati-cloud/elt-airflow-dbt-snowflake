-- Line-level facts rolled up to one row per claim.

select
    claim_id,
    count(*)                        as line_count,
    sum(units)                      as total_units,
    sum(line_billed_amount)         as lines_billed_amount,
    sum(line_paid_amount)           as lines_paid_amount,
    count(distinct procedure_code)  as distinct_procedures
from {{ ref('stg_claim_lines') }}
group by claim_id
