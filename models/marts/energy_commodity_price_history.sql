-- ---------------------------------------------------------------------------
-- energy_commodity_price_history
--
-- Business-facing commodity price fact. One row per trade date and commodity,
-- with the day-on-day move and a 30-day rolling average already computed, so a
-- trader or a natural-language question never has to write a window function.
--
-- Contract enforced (see _energy__marts.yml), so every column is cast
-- explicitly.
--
-- Grain: one row per price_date and commodity_code.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with prices as (

    select * from {{ ref('int_energy_commodity_prices_unpivoted') }}

),

with_movement as (

    select
        prices.*,

        -- Previous observation for the same commodity. Because UNPIVOT dropped
        -- the days a commodity did not trade, "previous" means the previous day
        -- it actually traded, which is what a trader means too.
        lag(price_usd) over (
            partition by commodity_code
            order by price_date
        ) as previous_price_usd,

        -- Trailing 30 observations including today.
        avg(price_usd) over (
            partition by commodity_code
            order by price_date
            rows between 29 preceding and current row
        ) as rolling_30d_avg_price

    from prices

)

select

    -- ---- keys and time ------------------------------------------------------
    cast(price_date as date) as price_date,
    cast(commodity_code as varchar) as commodity_code,

    -- ---- dimensions ----------------------------------------------------------
    cast(commodity_name as varchar) as commodity_name,
    cast(commodity_group as varchar) as commodity_group,
    cast(price_unit as varchar) as price_unit,
    cast(is_energy_complex as boolean) as is_energy_complex,

    -- ---- measures --------------------------------------------------------------
    cast(price_usd as number(18, 4)) as price_usd,
    cast(previous_price_usd as number(18, 4)) as previous_price_usd,
    cast(price_usd - previous_price_usd as number(18, 4)) as price_change_usd,

    -- nullif() guards the first observation of each commodity, where there is
    -- no previous price, and the 2020 oil crash, where the previous price was
    -- negative and a percentage would be meaningless.
    cast(
        (price_usd - previous_price_usd) / nullif(abs(previous_price_usd), 0)
        as number(18, 6)
    ) as price_change_pct,

    cast(rolling_30d_avg_price as number(18, 4)) as rolling_30d_avg_price

from with_movement
