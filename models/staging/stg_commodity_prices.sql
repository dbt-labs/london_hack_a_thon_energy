-- ---------------------------------------------------------------------------
-- stg_commodity_prices
--
-- Typed view over the wide commodity price feed. Still one column per
-- commodity: reshaping happens in the intermediate layer, because that is a
-- modelling decision and staging should not make modelling decisions.
--
-- The one thing this model does decide is to drop the fully-null row. The
-- source has a single row (2000-01-03) where every price is null. It is not a
-- real trading day for our purposes and it would show up as a gap in every
-- chart downstream.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with source as (

    select * from {{ ref('commodity_prices') }}

),

renamed as (

    select

        -- ---- keys and time ------------------------------------------------
        cast(id as number(38, 0)) as price_row_id,
        cast(date as date) as price_date,

        -- ---- energy complex --------------------------------------------------
        cast(natural_gas as number(18, 4)) as natural_gas,
        cast(wti_crude as number(18, 4)) as wti_crude,
        cast(brent_crude as number(18, 4)) as brent_crude,
        cast(low_sulphur_gas_oil as number(18, 4)) as low_sulphur_gas_oil,
        cast(uls_diesel as number(18, 4)) as uls_diesel,
        cast(gasoline as number(18, 4)) as gasoline,

        -- ---- metals -----------------------------------------------------------
        cast(gold as number(18, 4)) as gold,
        cast(silver as number(18, 4)) as silver,
        cast(copper as number(18, 4)) as copper,
        cast(aluminium as number(18, 4)) as aluminium,
        cast(nickel as number(18, 4)) as nickel,
        cast(zinc as number(18, 4)) as zinc,

        -- ---- grains and softs ---------------------------------------------------
        cast(corn as number(18, 4)) as corn,
        cast(wheat as number(18, 4)) as wheat,
        cast(hrw_wheat as number(18, 4)) as hrw_wheat,
        cast(soybeans as number(18, 4)) as soybeans,
        cast(soybean_oil as number(18, 4)) as soybean_oil,
        cast(soybean_meal as number(18, 4)) as soybean_meal,
        cast(sugar as number(18, 4)) as sugar,
        cast(coffee as number(18, 4)) as coffee,
        cast(cotton as number(18, 4)) as cotton,

        -- ---- livestock ----------------------------------------------------------
        cast(live_cattle as number(18, 4)) as live_cattle,
        cast(lean_hogs as number(18, 4)) as lean_hogs

    from source

    -- Drop the single all-null row. Brent is a good proxy for "did this row
    -- carry any prices at all", because it is populated on every real day.
    where brent_crude is not null

)

select * from renamed
