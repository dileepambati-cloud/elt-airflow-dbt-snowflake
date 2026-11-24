-- Claim service lines, one row per claim_id + line_number.

with source as (

    select * from {{ source('raw', 'claim_lines') }}

)

select
    trim(claim_id) || '-' || cast(line_number as varchar)  as claim_line_id,
    trim(claim_id)                                          as claim_id,
    cast(line_number as integer)                            as line_number,
    trim(cast(procedure_code as varchar))                   as procedure_code,
    cast(units as integer)                                  as units,
    cast(line_billed_amount as decimal(12, 2))              as line_billed_amount,
    cast(line_paid_amount as decimal(12, 2))                as line_paid_amount
from source
