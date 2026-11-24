-- Provider dimension plus one "unknown" row.
-- Claims whose provider isn't in the directory point at UNKNOWN instead of
-- dropping out of joins, so paid totals always reconcile.

with providers as (

    select
        provider_id,
        npi,
        provider_name,
        specialty,
        state
    from {{ ref('stg_providers') }}

),

unknown as (

    select
        'UNKNOWN'                as provider_id,
        cast(null as varchar)    as npi,
        'Unknown provider'       as provider_name,
        'Unknown'                as specialty,
        cast(null as varchar)    as state

)

select * from providers
union all
select * from unknown
