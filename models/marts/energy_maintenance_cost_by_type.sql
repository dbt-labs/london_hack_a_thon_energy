-- ---------------------------------------------------------------------------
-- energy_maintenance_cost_by_type
--
-- Maintenance economics rolled up to the strategy level. This is the table the
-- reliability lead brings to the monthly review: what is each maintenance
-- strategy costing us, and how much downtime is it buying or avoiding?
--
-- Contract enforced (see _energy__marts.yml).
--
-- Grain: one row per maintenance_type.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with logs as (

    select * from {{ ref('energy_maintenance_logs') }}

),

aggregated as (

    select
        maintenance_type,

        -- HOL_BUG_ENERGY_02
        maintenance_status,

        count(*) as event_count,
        count(distinct equipment_id) as equipment_count,
        count(distinct technician_id) as technician_count,

        sum(maintenance_cost) as total_maintenance_cost,
        avg(maintenance_cost) as average_maintenance_cost,
        sum(downtime_hours) as total_downtime_hours,
        avg(downtime_hours) as average_downtime_hours,
        avg(failure_rate) as average_failure_rate,
        sum(summarization_hours_saved) as total_summarization_hours_saved,

        sum(case when is_completed then 1 else 0 end) as completed_event_count,
        sum(case when is_at_risk then 1 else 0 end) as at_risk_event_count

    from logs
    group by maintenance_type

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(maintenance_type as varchar) as maintenance_type,

    -- ---- volumes -------------------------------------------------------------
    cast(event_count as number(38, 0)) as event_count,
    cast(equipment_count as number(38, 0)) as equipment_count,
    cast(technician_count as number(38, 0)) as technician_count,

    -- ---- cost ---------------------------------------------------------------
    cast(total_maintenance_cost as number(18, 2)) as total_maintenance_cost,
    cast(average_maintenance_cost as number(18, 2)) as average_maintenance_cost,

    -- ---- downtime -------------------------------------------------------------
    cast(total_downtime_hours as number(38, 0)) as total_downtime_hours,
    cast(average_downtime_hours as number(18, 4)) as average_downtime_hours,
    cast(average_failure_rate as number(9, 4)) as average_failure_rate,

    -- Cost of an hour of downtime under this strategy. The number the
    -- reliability lead actually argues about.
    cast(
        total_maintenance_cost / nullif(total_downtime_hours, 0)
        as number(18, 2)
    ) as cost_per_downtime_hour,

    -- ---- delivery -------------------------------------------------------------
    cast(completed_event_count as number(38, 0)) as completed_event_count,
    cast(at_risk_event_count as number(38, 0)) as at_risk_event_count,
    cast(
        completed_event_count / nullif(event_count, 0)
        as number(9, 6)
    ) as completion_rate,

    -- ---- AI value -------------------------------------------------------------
    cast(total_summarization_hours_saved as number(38, 0)) as total_summarization_hours_saved

from aggregated
