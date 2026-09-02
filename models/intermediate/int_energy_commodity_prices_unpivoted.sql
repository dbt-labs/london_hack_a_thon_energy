-- ---------------------------------------------------------------------------
-- int_energy_commodity_prices_unpivoted
--
-- Turns the wide price feed (one column per commodity) into a long fact (one
-- row per date and commodity). This is the single most useful reshape in the
-- energy track: wide is convenient for a trader's spreadsheet, long is what
-- every chart, metric and semantic layer wants.
--
-- Snowflake's UNPIVOT does the work in one statement. It also drops NULLs by
-- default, which is exactly right here: gasoline only starts partway through
-- the series, and we want it absent on the days it did not trade rather than
-- present as a zero.
--
-- Grain: one row per price_date and commodity_code.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with wide_prices as (

    select
        price_date,
        natural_gas,
        wti_crude,
        brent_crude,
        low_sulphur_gas_oil,
        uls_diesel,
        gasoline,
        gold,
        silver,
        copper,
        aluminium,
        nickel,
        zinc,
        corn,
        wheat,
        hrw_wheat,
        soybeans,
        soybean_oil,
        soybean_meal,
        sugar,
        coffee,
        cotton,
        live_cattle,
        lean_hogs
    from {{ ref('stg_commodity_prices') }}

),

unpivoted as (

    -- UNPIVOT produces the commodity name as an uppercase string, because that
    -- is how Snowflake stores the identifier. Lowercase it so it joins to the
    -- reference seed.
    select
        price_date,
        lower(commodity_code_raw) as commodity_code,
        price_usd
    from wide_prices
    unpivot (
        -- HOL_BUG_ENERGY_01
        price_usd for commodity_code_raw in (
            natural_gas,
            crude_oil,
            brent_crude,
            low_sulphur_gas_oil,
            uls_diesel,
            gasoline,
            gold,
            silver,
            copper,
            aluminium,
            nickel,
            zinc,
            corn,
            wheat,
            hrw_wheat,
            soybeans,
            soybean_oil,
            soybean_meal,
            sugar,
            coffee,
            cotton,
            live_cattle,
            lean_hogs
        )
    )

),

-- Attach the human-readable name, the group and the quoted unit. Keeping this
-- in a seed rather than a CASE statement means a trader can add a commodity by
-- editing a CSV, without touching SQL.
labelled as (

    select
        unpivoted.price_date,
        unpivoted.commodity_code,
        reference.commodity_name,
        reference.commodity_group,
        reference.price_unit,
        reference.is_energy_complex,
        unpivoted.price_usd

    from unpivoted
    inner join {{ ref('commodity_reference') }} as reference
        on unpivoted.commodity_code = reference.commodity_code

)

select * from labelled
