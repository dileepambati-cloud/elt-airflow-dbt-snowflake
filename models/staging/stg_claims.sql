-- Claim headers, one row per claim_id.
--
-- The raw feed is append-only and the same claim can be delivered more than
-- once (PENDING first, final status later). Keep the most recent delivery.

with source as (

    select * from {{ source('raw', 'claims') }}

),

typed as (

    select
        trim(claim_id)                          as claim_id,
        trim(member_id)                         as member_id,
        trim(provider_id)                       as provider_id,
        upper(trim(claim_type))                 as claim_type,
        cast(service_date as date)              as service_date,
        cast(received_date as date)             as received_date,
        upper(trim(claim_status))               as claim_status,
        cast(billed_amount as decimal(12, 2))   as billed_amount,
        cast(paid_amount as decimal(12, 2))     as paid_amount,
        cast(_loaded_at as timestamp)           as loaded_at
    from source

),

ranked as (

    select
        *,
        row_number() over (
            partition by claim_id
            order by loaded_at desc
        ) as delivery_rank,
        count(*) over (partition by claim_id) as times_delivered
    from typed

)

select
    claim_id,
    member_id,
    provider_id,
    claim_type,
    service_date,
    received_date,
    claim_status,
    billed_amount,
    paid_amount,
    loaded_at,
    times_delivered
from ranked
where delivery_rank = 1
