-- Singular test: the de-duplication in int_energy_maintenance_logs_unioned has
-- to actually work, because nothing else in the project would notice if it
-- stopped.
--
-- Both source feeds carry all 750 events. Union without de-duplication and
-- every energy metric doubles, silently and plausibly. This test is the only
-- thing standing between that and a dashboard.

select
    maintenance_log_id,
    count(*) as row_count

from {{ ref('energy_maintenance_logs') }}

group by maintenance_log_id
having count(*) > 1
