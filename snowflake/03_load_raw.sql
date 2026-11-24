-- =====================================================================
-- Load one batch of extracts from the stage into the raw tables.
--
-- Files are uploaded first (Airflow does this, or by hand with snowsql):
--   PUT file://data/raw/members.csv     @payer.raw.raw_stage/members/     auto_compress = true;
--   PUT file://data/raw/providers.csv   @payer.raw.raw_stage/providers/   auto_compress = true;
--   PUT file://data/raw/claims.csv      @payer.raw.raw_stage/claims/      auto_compress = true;
--   PUT file://data/raw/claim_lines.csv @payer.raw.raw_stage/claim_lines/ auto_compress = true;
--
-- COPY keeps load history for 64 days, so re-running this for files that
-- were already loaded is a no-op - safe to retry.
-- =====================================================================

use role loader;
use warehouse load_wh;
use schema payer.raw;

-- members / providers are full snapshots of the source: replace them
truncate table members;
copy into members
    from @raw_stage/members/
    match_by_column_name = case_insensitive
    include_metadata = (_file_name = metadata$filename)
    on_error = abort_statement
    force = true;            -- full refresh: reload even if the file name was seen before

truncate table providers;
copy into providers
    from @raw_stage/providers/
    match_by_column_name = case_insensitive
    include_metadata = (_file_name = metadata$filename)
    on_error = abort_statement
    force = true;

-- claims / lines are incremental: append new files only
copy into claims
    from @raw_stage/claims/
    match_by_column_name = case_insensitive
    include_metadata = (_file_name = metadata$filename)
    on_error = abort_statement;

copy into claim_lines
    from @raw_stage/claim_lines/
    match_by_column_name = case_insensitive
    include_metadata = (_file_name = metadata$filename)
    on_error = abort_statement;

-- quick check of what just landed
select 'members' as tbl, count(*) as row_count from members
union all select 'providers', count(*) from providers
union all select 'claims', count(*) from claims
union all select 'claim_lines', count(*) from claim_lines;
