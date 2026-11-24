-- Header billed/paid amounts should equal the sum of their lines (to the cent).
-- Warn only: upstream adjustments sometimes land on the header first.

{{ config(severity = 'warn') }}

with line_totals as (

    select
        claim_id,
        sum(line_billed_amount) as lines_billed,
        sum(line_paid_amount)   as lines_paid
    from {{ ref('stg_claim_lines') }}
    group by claim_id

)

select
    c.claim_id,
    c.billed_amount,
    l.lines_billed,
    c.paid_amount,
    l.lines_paid
from {{ ref('stg_claims') }} c
join line_totals l on l.claim_id = c.claim_id
where abs(c.billed_amount - l.lines_billed) > 0.01
   or abs(c.paid_amount - l.lines_paid) > 0.01
