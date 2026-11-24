-- fct_claims must carry every claim and every dollar from stg_claims.
-- Catches joins that drop or duplicate rows (e.g. an unmatched provider).

with fct as (
    select count(*) as claims, sum(paid_amount) as paid, sum(billed_amount) as billed
    from {{ ref('fct_claims') }}
),

stg as (
    select count(*) as claims, sum(paid_amount) as paid, sum(billed_amount) as billed
    from {{ ref('stg_claims') }}
)

select fct.*, stg.claims as stg_claims, stg.paid as stg_paid, stg.billed as stg_billed
from fct cross join stg
where fct.claims <> stg.claims
   or abs(fct.paid - stg.paid) > 0.01
   or abs(fct.billed - stg.billed) > 0.01
