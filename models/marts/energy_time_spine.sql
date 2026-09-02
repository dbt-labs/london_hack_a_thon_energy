-- ---------------------------------------------------------------------------
-- energy_time_spine
--
-- One row per calendar day. The semantic layer requires a time spine at DAY
-- granularity or smaller before it will serve any metric that has a time
-- dimension, which every metric in this track does (price_date, log_date).
--
-- Without this model, dbt platform commands (including dbt seed, since it
-- validates the semantic manifest before running anything) fail with:
-- "The semantic layer requires a time spine model with granularity DAY or
-- smaller."
--
-- Range is wide on purpose so it comfortably covers the seed data and years
-- of future demo runs without needing to be touched again.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with base_dates as (
    {{ dbt.date_spine(
        'day',
        "cast('2015-01-01' as date)",
        "cast('2035-01-01' as date)"
    ) }}
)

select
    cast(date_day as date) as date_day
from base_dates
