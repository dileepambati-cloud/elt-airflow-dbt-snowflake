-- =====================================================================
-- Raw layer objects: file format, internal stage and raw tables.
-- Columns match the CSV headers produced by scripts/generate_raw_data.py.
-- Run as LOADER.
-- =====================================================================

use role loader;
use warehouse load_wh;
use schema payer.raw;

create file format if not exists csv_with_header
    type = csv
    parse_header = true               -- lets COPY match columns by name
    field_optionally_enclosed_by = '"'
    null_if = ('', 'NULL')
    empty_field_as_null = true
    trim_space = false                -- keep values exactly as delivered; staging trims
    error_on_column_count_mismatch = true;

create stage if not exists raw_stage
    file_format = csv_with_header
    comment = 'Landing area for payer extracts (PUT from Airflow / snowsql)';

create table if not exists members (
    member_id       varchar,
    first_name      varchar,
    last_name       varchar,
    date_of_birth   date,
    gender          varchar,
    plan_code       varchar,
    zip_code        varchar,
    effective_date  date,
    updated_at      timestamp_ntz,
    _file_name      varchar,
    _copied_at      timestamp_ltz default current_timestamp()
);

create table if not exists providers (
    provider_id     varchar,
    npi             varchar,
    provider_name   varchar,
    specialty       varchar,
    state           varchar,
    _file_name      varchar,
    _copied_at      timestamp_ltz default current_timestamp()
);

-- append-only: the same claim_id can arrive more than once
create table if not exists claims (
    claim_id        varchar,
    member_id       varchar,
    provider_id     varchar,
    claim_type      varchar,
    service_date    date,
    received_date   date,
    claim_status    varchar,
    billed_amount   number(12, 2),
    paid_amount     number(12, 2),
    _loaded_at      timestamp_ntz,
    _file_name      varchar,
    _copied_at      timestamp_ltz default current_timestamp()
);

create table if not exists claim_lines (
    claim_id            varchar,
    line_number         integer,
    procedure_code      varchar,
    units               integer,
    line_billed_amount  number(12, 2),
    line_paid_amount    number(12, 2),
    _file_name          varchar,
    _copied_at          timestamp_ltz default current_timestamp()
);
