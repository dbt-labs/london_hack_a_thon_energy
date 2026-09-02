-- ---------------------------------------------------------------------------
-- energy_maintenance_logs
--
-- Business-facing maintenance fact. One row per maintenance event, after the
-- two source feeds have been combined and de-duplicated.
--
-- Contract enforced (see _energy__marts.yml), so every column is cast
-- explicitly.
--
-- Grain: one row per maintenance_log_id.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with logs as (

    select * from {{ ref('int_energy_maintenance_logs_unioned') }}

),

classified as (

    select
        logs.*,

        -- ---- derived: how disruptive was this event -----------------------
        -- Reliability engineers band downtime rather than reading raw hours,
        -- because the operational response differs by band.
        case
            when downtime_hours >= 8 then 'Major'
            when downtime_hours >= 4 then 'Moderate'
            else 'Minor'
        end as downtime_band,

        -- ---- derived: planned versus unplanned -------------------------------
        -- The single most watched split in maintenance. Corrective work is
        -- something breaking; everything else is work you chose to do.
        case
            when maintenance_type = 'Corrective Maintenance' then 'Unplanned'
            else 'Planned'
        end as work_class,

        -- ---- derived: is the event finished ------------------------------------
        case
            when maintenance_status = 'Completed' then true
            else false
        end as is_completed,

        case
            when maintenance_status in ('Delayed', 'Cancelled') then true
            else false
        end as is_at_risk,

        -- ---- derived: cost per hour of downtime ---------------------------------
        round(maintenance_cost / nullif(downtime_hours, 0), 2) as cost_per_downtime_hour

    from logs

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(maintenance_log_id as varchar) as maintenance_log_id,
    cast(equipment_id as varchar) as equipment_id,
    cast(technician_id as varchar) as technician_id,
    cast(customer_id as varchar) as customer_id,
    cast(erp_order_id as varchar) as erp_order_id,

    -- ---- time ---------------------------------------------------------------
    cast(log_date as date) as log_date,

    -- ---- dimensions ----------------------------------------------------------
    cast(maintenance_type as varchar) as maintenance_type,
    cast(maintenance_status as varchar) as maintenance_status,
    cast(downtime_band as varchar) as downtime_band,
    cast(work_class as varchar) as work_class,
    cast(source_system as varchar) as source_system,

    -- ---- measures --------------------------------------------------------------
    cast(failure_rate as number(9, 4)) as failure_rate,
    cast(maintenance_cost as number(18, 2)) as maintenance_cost,
    cast(downtime_hours as number(38, 0)) as downtime_hours,
    cast(cost_per_downtime_hour as number(18, 2)) as cost_per_downtime_hour,
    cast(summarization_hours_saved as number(38, 0)) as summarization_hours_saved,

    -- ---- flags -----------------------------------------------------------------
    cast(is_completed as boolean) as is_completed,
    cast(is_at_risk as boolean) as is_at_risk,
    cast(is_reported_by_both_feeds as boolean) as is_reported_by_both_feeds,

    -- ---- text ---------------------------------------------------------------
    cast(summarized_log as varchar) as summarized_log

from classified
