{{
    config(
        materialized = 'incremental',
        unique_key = 'claim_id',
        on_schema_change = 'append_new_columns'
    )
}}

-- One row per claim. Incremental: each run only picks up claims delivered
-- since the last load (plus a 3-day lookback for late re-deliveries) and
-- merges them on claim_id, so a re-delivered claim updates in place.

with claims as (

    select * from {{ ref('stg_claims') }}

    {% if is_incremental() %}
    where loaded_at > (
        select {{ dbt.dateadd('day', -3, 'max(loaded_at)') }} from {{ this }}
    )
    {% endif %}

),

lines as (

    select * from {{ ref('int_claim_line_summary') }}

),

providers as (

    select provider_id from {{ ref('dim_provider') }}

)

select
    c.claim_id,
    c.member_id,
    coalesce(p.provider_id, 'UNKNOWN')                  as provider_id,
    c.provider_id                                       as source_provider_id,
    c.claim_type,
    c.claim_status,
    c.service_date,
    cast({{ dbt.date_trunc('month', 'c.service_date') }} as date) as service_month,
    c.received_date,
    {{ dbt.datediff('c.service_date', 'c.received_date', 'day') }} as days_to_receive,
    c.billed_amount,
    c.paid_amount,
    coalesce(l.line_count, 0)                           as line_count,
    coalesce(l.total_units, 0)                          as total_units,
    c.claim_status = 'DENIED'                           as is_denied,
    c.times_delivered,
    c.loaded_at
from claims c
left join lines l on l.claim_id = c.claim_id
left join providers p on p.provider_id = c.provider_id
