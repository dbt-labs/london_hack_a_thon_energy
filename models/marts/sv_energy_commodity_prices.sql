-- ---------------------------------------------------------------------------
-- sv_energy_commodity_prices
--
-- A Snowflake Semantic View over the commodity price fact.
--
-- The energy track ships two semantic views rather than one, because commodity
-- trading and equipment maintenance are genuinely separate subject areas with
-- no key in common. Forcing them into one object would give Cortex Analyst a
-- join it cannot make and questions it cannot answer. One semantic view per
-- subject area is the honest shape.
--
-- Compare with the `semantic_model:` and `metrics:` blocks in
-- _energy__marts.yml, which express the same ideas as dbt Semantic Layer
-- (MetricFlow) specs.
--
-- Note for the room: this data ends on 2022-11-04. Ask "in 2022", not "this
-- year", or the agent will correctly tell you there is nothing to report.
-- ---------------------------------------------------------------------------

{{ config(materialized='semantic_view') }}

TABLES (

    prices AS {{ ref('energy_commodity_price_history') }}
        PRIMARY KEY (price_date, commodity_code)
        WITH SYNONYMS = ('prices', 'commodity prices', 'market data', 'settlements')
        COMMENT = 'Daily settlement prices for 23 traded commodities, 2000 to 2022.'

)

FACTS (

    prices.settlement_price AS prices.price_usd
        COMMENT = 'Settlement price on the day, in the unit given by price_unit.',

    prices.prior_settlement_price AS prices.previous_price_usd
        COMMENT = 'Settlement price on the previous day the commodity traded.',

    prices.daily_change AS prices.price_change_usd
        COMMENT = 'Day-on-day move in the settlement price.',

    prices.daily_change_pct AS prices.price_change_pct
        COMMENT = 'Day-on-day move as a share of the previous price.',

    prices.rolling_30d_price AS prices.rolling_30d_avg_price
        COMMENT = 'Average settlement price over the trailing 30 trading days.'

)

DIMENSIONS (

    prices.price_date AS prices.price_date
        WITH SYNONYMS = ('date', 'trade date', 'trading day', 'when')
        COMMENT = 'Trade date. The series runs from 2000-01-04 to 2022-11-04.',

    prices.commodity AS prices.commodity_name
        WITH SYNONYMS = ('commodity', 'product', 'instrument', 'contract')
        COMMENT = 'Human-readable commodity name, for example Brent crude or Gold.',

    prices.commodity_code AS prices.commodity_code
        WITH SYNONYMS = ('commodity code', 'ticker')
        COMMENT = 'Machine-readable commodity code, for example brent_crude.',

    prices.commodity_group AS prices.commodity_group
        WITH SYNONYMS = ('group', 'asset class', 'sector', 'complex')
        COMMENT = 'Energy, Metals, Grains and softs, or Livestock.',

    prices.price_unit AS prices.price_unit
        WITH SYNONYMS = ('unit', 'quoted in', 'units')
        COMMENT = 'The unit the price is quoted in, for example USD per barrel.'

)

METRICS (

    prices.average_price AS AVG(prices.settlement_price)
        WITH SYNONYMS = ('average price', 'mean price', 'typical price')
        COMMENT = 'Average settlement price over the selected period.',

    prices.latest_price AS MAX_BY(prices.settlement_price, prices.price_date)
        WITH SYNONYMS = ('latest price', 'last price', 'closing price', 'current price')
        COMMENT = 'Settlement price on the most recent trade date in the selection.',

    prices.highest_price AS MAX(prices.settlement_price)
        WITH SYNONYMS = ('high', 'peak price', 'highest price', 'maximum')
        COMMENT = 'Highest settlement price over the selected period.',

    prices.lowest_price AS MIN(prices.settlement_price)
        WITH SYNONYMS = ('low', 'trough price', 'lowest price', 'minimum')
        COMMENT = 'Lowest settlement price over the selected period.',

    prices.price_volatility AS STDDEV(prices.settlement_price)
        WITH SYNONYMS = ('volatility', 'price volatility', 'how volatile')
        COMMENT = 'Standard deviation of the settlement price over the period.',

    prices.average_daily_change_pct AS AVG(prices.daily_change_pct)
        WITH SYNONYMS = ('average daily move', 'average change', 'typical daily move')
        COMMENT = 'Average day-on-day price move as a share of the previous price.',

    prices.largest_daily_gain_pct AS MAX(prices.daily_change_pct)
        WITH SYNONYMS = ('biggest gain', 'largest rise', 'best day')
        COMMENT = 'Largest single-day percentage gain over the period.',

    prices.largest_daily_loss_pct AS MIN(prices.daily_change_pct)
        WITH SYNONYMS = ('biggest drop', 'largest fall', 'worst day')
        COMMENT = 'Largest single-day percentage loss over the period.',

    prices.trading_day_count AS COUNT(prices.price_date)
        WITH SYNONYMS = ('trading days', 'number of observations', 'how many days')
        COMMENT = 'Number of trading days in the selection.'

)

COMMENT = 'Commodity price history for the energy track of the Openflow, Snowflake and dbt hands-on lab. Covers 2000-01-04 to 2022-11-04.'
