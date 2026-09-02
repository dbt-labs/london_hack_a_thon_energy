-- Singular test: the unpivot should produce all 23 commodities from the
-- reference seed. If someone adds a commodity to the seed but forgets to add
-- the column to the UNPIVOT list, this catches it. That is a genuinely easy
-- mistake to make, because the seed and the SQL are in different files.

with expected as (

    select commodity_code from {{ ref('commodity_reference') }}

),

actual as (

    select distinct commodity_code from {{ ref('energy_commodity_price_history') }}

)

select expected.commodity_code

from expected
left join actual
    on expected.commodity_code = actual.commodity_code

where actual.commodity_code is null
