-- One row per member, cleaned and typed.

with source as (

    select * from {{ source('raw', 'members') }}

),

cleaned as (

    select
        trim(member_id)                         as member_id,
        trim(first_name)                        as first_name,
        trim(last_name)                         as last_name,
        cast(date_of_birth as date)             as date_of_birth,
        upper(trim(gender))                     as gender,
        upper(trim(plan_code))                  as plan_code,
        -- keep leading zeros
        lpad(trim(cast(zip_code as varchar)), 5, '0') as zip_code,
        cast(effective_date as date)            as effective_date,
        cast(updated_at as timestamp)           as updated_at
    from source

)

select * from cleaned
