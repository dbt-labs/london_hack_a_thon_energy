-- ---------------------------------------------------------------------------
-- stg_fts_records
--
-- Typed, renamed view over the field technician system maintenance log.
--
-- The only thing here that is not a straight rename is `source_system`. Adding
-- a literal column that names the feed is the cheapest possible lineage: once
-- two feeds are unioned downstream, every row still knows where it came from.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('fts_records') }}

),

renamed as (

    select

        -- ---- provenance -----------------------------------------------------
        'FTS' as source_system,

        -- ---- keys -------------------------------------------------------------
        cast(record_id as varchar) as maintenance_log_id,
        cast(equipment_id as varchar) as equipment_id,
        cast(technician_id as varchar) as technician_id,
        cast(customer_id as varchar) as customer_id,
        cast(erp_order_id as varchar) as erp_order_id,

        -- ---- time ---------------------------------------------------------------
        -- Source Postgres column is `text` holding ISO YYYY-MM-DD.
        cast(log_date as date) as log_date,

        -- ---- dimensions ----------------------------------------------------------
        initcap(cast(maintenance_type as varchar)) as maintenance_type,
        initcap(cast(maintenance_status as varchar)) as maintenance_status,

        -- ---- measures --------------------------------------------------------------
        cast(failure_rate as number(9, 4)) as failure_rate,
        cast(maintenance_cost as number(18, 2)) as maintenance_cost,
        cast(downtime_hours as number(38, 0)) as downtime_hours,
        cast(summarization_time_saved as number(38, 0)) as summarization_hours_saved,

        -- ---- text ---------------------------------------------------------------
        cast(log_description as varchar) as log_description,
        cast(summarized_log as varchar) as summarized_log

    from source

)

select * from renamed
