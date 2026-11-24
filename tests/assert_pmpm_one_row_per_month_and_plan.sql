select month_start, plan_code, count(*) as row_count
from {{ ref('mart_pmpm_monthly') }}
group by month_start, plan_code
having count(*) > 1
