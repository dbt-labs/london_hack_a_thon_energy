-- ---------------------------------------------------------------------------
-- int_energy_maintenance_logs_unioned
--
-- Combines the two maintenance feeds into one. This is the model to read
-- carefully, because the naive version of it is wrong in a way nothing warns
-- you about.
--
-- The two feeds are NOT two sets of events. LogLynx mirrors the field
-- technician system: all 750 record_ids appear in both, and no row differs on
-- any column. Union them and stop, and every energy metric doubles. Total
-- maintenance cost goes from about $410k to about $820k, and it looks
-- perfectly plausible.
--
-- So: union, then de-duplicate. The field technician system is the system of
-- record, so where the same event appears in both, FTS wins. `source_system`
-- survives on the row, so you can always prove which feed the surviving record
-- came from, and count how many were duplicated.
--
-- Grain: one row per maintenance_log_id.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with fts as (

    select * from {{ ref('stg_fts_records') }}

),

loglynx as (

    select * from {{ ref('stg_loglynx') }}

),

-- Stack the two feeds. Both staging models were written to the same shape on
-- purpose, so this is a plain union all with no column gymnastics.
combined as (

    select * from fts

    union all

    select * from loglynx

),

-- Rank the copies of each event. FTS is the system of record, so it sorts
-- first and wins. If a third feed ever arrives, it joins the priority list
-- here and nothing else in the project changes.
ranked as (

    select
        combined.*,

        row_number() over (
            partition by maintenance_log_id
            order by
                case source_system
                    when 'FTS' then 1
                    when 'LOGLYNX' then 2
                    else 99
                end
        ) as source_priority,

        -- How many feeds reported this event. 1 means it is unique to one
        -- system, 2 means both systems saw it. This column is the evidence for
        -- the de-duplication, so it stays on the row.
        count(*) over (partition by maintenance_log_id) as feed_count

    from combined

),

deduplicated as (

    select
        source_system,
        maintenance_log_id,
        equipment_id,
        technician_id,
        customer_id,
        erp_order_id,
        log_date,
        maintenance_type,
        maintenance_status,
        failure_rate,
        maintenance_cost,
        downtime_hours,
        summarization_hours_saved,
        log_description,
        summarized_log,

        feed_count,
        case when feed_count > 1 then true else false end as is_reported_by_both_feeds

    from ranked
    where source_priority = 1

)

select * from deduplicated
