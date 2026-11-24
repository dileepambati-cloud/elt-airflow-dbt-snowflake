-- Paid per member per month (PMPM) by plan - the standard payer cost metric.
--
--   member_months = members enrolled (effective_date on or before month end)
--   pmpm          = paid_amount / member_months
--
-- Plan comes from the member's current version in dim_member.

with months as (

    select distinct service_month as month_start
    from {{ ref('fct_claims') }}

),

members as (

    select member_id, plan_code, effective_date
    from {{ ref('dim_member') }}
    where is_current

),

member_months as (

    select
        m.month_start,
        mb.plan_code,
        count(*) as member_months
    from months m
    join members mb
      on mb.effective_date <= {{ dbt.last_day('m.month_start', 'month') }}
    group by m.month_start, mb.plan_code

),

claims as (

    select
        f.service_month                                   as month_start,
        mb.plan_code,
        count(*)                                          as claim_count,
        sum(case when f.is_denied then 1 else 0 end)      as denied_count,
        sum(f.billed_amount)                              as billed_amount,
        sum(f.paid_amount)                                as paid_amount
    from {{ ref('fct_claims') }} f
    join members mb on mb.member_id = f.member_id
    group by f.service_month, mb.plan_code

)

select
    mm.month_start,
    mm.plan_code,
    mm.member_months,
    coalesce(c.claim_count, 0)                                        as claim_count,
    coalesce(c.denied_count, 0)                                       as denied_count,
    coalesce(c.billed_amount, 0)                                      as billed_amount,
    coalesce(c.paid_amount, 0)                                        as paid_amount,
    round(coalesce(c.paid_amount, 0) / mm.member_months, 2)           as pmpm,
    round(100.0 * coalesce(c.denied_count, 0)
          / nullif(c.claim_count, 0), 2)                              as denial_rate_pct
from member_months mm
left join claims c
  on c.month_start = mm.month_start
 and c.plan_code = mm.plan_code
