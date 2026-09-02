-- ---------------------------------------------------------------------------
-- vw_energy_data_quality
--
-- A composite data-quality scorecard, one row per data domain.
--
-- This is the model the lab uses to tour dbt Studio and Fusion. It is built
-- from a chain of small CTEs on purpose: each one is short enough to read, and
-- each one can be previewed on its own in dbt Studio without running the whole
-- model. Hover any column to see the type Fusion inferred, and break a ref() to
-- watch the error appear before you run anything.
--
-- It reads from staging rather than from the marts, deliberately. The most
-- important finding in this track (that two feeds report the same 750 events)
-- is only visible before de-duplication.
--
-- Grain: one row per data_domain.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with prices as (

    select * from {{ ref('stg_commodity_prices') }}

),

fts as (

    select * from {{ ref('stg_fts_records') }}

),

loglynx as (

    select * from {{ ref('stg_loglynx') }}

),

-- ---- commodity price checks -------------------------------------------------
-- Three questions, one per quality dimension. Note that a negative price is
-- counted as a validity finding but is not necessarily an error: WTI settled
-- below zero on 2020-04-20 and that is a real market event. Data quality
-- scoring surfaces things to look at; a human decides what they mean.
price_checks as (

    select
        'Commodity prices' as data_domain,
        count(*) as total_rows,

        -- completeness: a benchmark price missing on a trading day
        sum(case when brent_crude is null then 1 else 0 end)
            + sum(case when wti_crude is null then 1 else 0 end)
            + sum(case when natural_gas is null then 1 else 0 end)
            as completeness_failures,
        3 as completeness_checks,

        -- validity: prices at or below zero
        sum(case when brent_crude <= 0 then 1 else 0 end)
            + sum(case when wti_crude <= 0 then 1 else 0 end)
            + sum(case when natural_gas <= 0 then 1 else 0 end)
            + sum(case when gold <= 0 then 1 else 0 end)
            as validity_failures,
        4 as validity_checks,

        -- consistency: Brent and WTI track each other closely. A spread wider
        -- than 40 USD is either a real dislocation or a bad print.
        sum(case when abs(brent_crude - wti_crude) > 40 then 1 else 0 end)
            + sum(case when gasoline is null then 1 else 0 end)
            as consistency_failures,
        2 as consistency_checks

    from prices

),

-- ---- maintenance log checks -----------------------------------------------
-- The overlap between the two feeds is computed here, before de-duplication,
-- because it is invisible afterwards.
maintenance_overlap as (

    select count(*) as duplicated_event_count
    from fts
    inner join loglynx
        on fts.maintenance_log_id = loglynx.maintenance_log_id

),

maintenance_checks as (

    select
        'Maintenance logs' as data_domain,
        count(*) as total_rows,

        -- completeness
        sum(case when summarized_log is null or trim(summarized_log) = '' then 1 else 0 end)
            + sum(case when equipment_id is null or trim(equipment_id) = '' then 1 else 0 end)
            + sum(case when technician_id is null or trim(technician_id) = '' then 1 else 0 end)
            as completeness_failures,
        3 as completeness_checks,

        -- validity
        sum(case when failure_rate < 0 or failure_rate > 1 then 1 else 0 end)
            + sum(case when maintenance_cost <= 0 then 1 else 0 end)
            + sum(case when downtime_hours < 0 then 1 else 0 end)
            as validity_failures,
        3 as validity_checks,

        -- consistency: every one of these events is reported twice, once by
        -- each system. That is the single biggest quality problem in the track.
        (select duplicated_event_count from maintenance_overlap)
            + sum(case when maintenance_status = 'Completed' and downtime_hours = 0 then 1 else 0 end)
            as consistency_failures,
        2 as consistency_checks

    from fts

),

-- ---- combine and score --------------------------------------------------------
-- Each dimension starts at 100 and loses the percentage of checks that failed.
combined as (

    select * from price_checks
    union all
    select * from maintenance_checks

),

scored as (

    select
        data_domain,
        total_rows,
        completeness_failures,
        validity_failures,
        consistency_failures,

        round(
            100 - (100.0 * completeness_failures / nullif(total_rows * completeness_checks, 0)),
            2
        ) as completeness_score,

        round(
            100 - (100.0 * validity_failures / nullif(total_rows * validity_checks, 0)),
            2
        ) as validity_score,

        round(
            100 - (100.0 * consistency_failures / nullif(total_rows * consistency_checks, 0)),
            2
        ) as consistency_score

    from combined

),

final as (

    select
        data_domain,
        total_rows,
        completeness_score,
        validity_score,
        consistency_score,

        round((completeness_score + validity_score + consistency_score) / 3, 2) as data_quality_score,

        case
            when (completeness_score + validity_score + consistency_score) / 3 >= 95 then 'A'
            when (completeness_score + validity_score + consistency_score) / 3 >= 90 then 'B'
            when (completeness_score + validity_score + consistency_score) / 3 >= 80 then 'C'
            else 'D'
        end as data_quality_grade,

        completeness_failures,
        validity_failures,
        consistency_failures

    from scored

)

select * from final
order by data_quality_score asc
