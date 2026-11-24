-- One row per provider.

with source as (

    select * from {{ source('raw', 'providers') }}

)

select
    trim(provider_id)           as provider_id,
    trim(cast(npi as varchar))  as npi,
    trim(provider_name)         as provider_name,
    trim(specialty)             as specialty,
    upper(trim(state))          as state
from source
