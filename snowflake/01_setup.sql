-- =====================================================================
-- One-time Snowflake setup for the payer ELT.
-- Run as ACCOUNTADMIN (or SYSADMIN + SECURITYADMIN for the grants).
--
-- Roles
--   LOADER       - loads files into RAW (used by the Airflow load task)
--   TRANSFORMER  - reads RAW, builds STAGING / SNAPSHOTS / MARTS (used by dbt)
--   REPORTER     - read-only on MARTS (BI tools)
-- =====================================================================

use role sysadmin;

-- small warehouses that suspend quickly - this workload runs in short bursts
create warehouse if not exists load_wh
    warehouse_size = 'XSMALL' auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'COPY INTO raw tables';

create warehouse if not exists transform_wh
    warehouse_size = 'XSMALL' auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'dbt builds';

create warehouse if not exists report_wh
    warehouse_size = 'XSMALL' auto_suspend = 300 auto_resume = true initially_suspended = true
    comment = 'BI queries';

create database if not exists payer;
create schema if not exists payer.raw;
create schema if not exists payer.staging;
create schema if not exists payer.snapshots;
create schema if not exists payer.marts;

-- ---------------------------------------------------------------- roles
use role securityadmin;

create role if not exists loader;
create role if not exists transformer;
create role if not exists reporter;

grant role loader to role sysadmin;
grant role transformer to role sysadmin;
grant role reporter to role sysadmin;

-- LOADER: write RAW only
grant usage on warehouse load_wh to role loader;
grant usage on database payer to role loader;
grant usage, create table, create stage, create file format on schema payer.raw to role loader;
grant select, insert, truncate on all tables in schema payer.raw to role loader;
grant select, insert, truncate on future tables in schema payer.raw to role loader;

-- TRANSFORMER: read RAW, own everything downstream
grant usage on warehouse transform_wh to role transformer;
grant usage on database payer to role transformer;
grant usage on schema payer.raw to role transformer;
grant select on all tables in schema payer.raw to role transformer;
grant select on future tables in schema payer.raw to role transformer;
grant all on schema payer.staging to role transformer;
grant all on schema payer.snapshots to role transformer;
grant all on schema payer.marts to role transformer;

-- REPORTER: read MARTS only
grant usage on warehouse report_wh to role reporter;
grant usage on database payer to role reporter;
grant usage on schema payer.marts to role reporter;
grant select on all tables in schema payer.marts to role reporter;
grant select on future tables in schema payer.marts to role reporter;
grant select on all views in schema payer.marts to role reporter;
grant select on future views in schema payer.marts to role reporter;

-- service users (set passwords / key pairs outside of source control)
-- create user if not exists svc_airflow default_role = loader default_warehouse = load_wh;
-- create user if not exists svc_dbt     default_role = transformer default_warehouse = transform_wh;
-- grant role loader to user svc_airflow;
-- grant role transformer to user svc_dbt;
