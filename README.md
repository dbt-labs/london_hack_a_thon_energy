# Energy track

Commodity price history and equipment reliability for an energy operator.
Two subject areas, three source tables, and the most interesting data-quality
problem in the whole lab.

This file is the 30-second orientation. The full step-by-step attendee
walkthrough is distributed separately by the workshop facilitators.

## Support and maintenance

This project is provided as-is, without warranties or SLAs. It is workshop
material, maintained on a best-effort basis by the dbt Labs sales engineering
team.

Bug reports and questions are welcome as GitHub issues, but there is no
committed response time. For security reports, see [SECURITY.md](SECURITY.md).
Nothing here implies contractual support from dbt Labs.

<!-- TODO(luis): commodity_prices.csv is described below as containing real
     market data (the 2020-04-20 WTI settlement). Confirm its provenance and
     redistribution terms before this repo goes public, and add an attribution
     note here. See the note in the review summary. -->


## The business question

> What is our exposure to commodity prices, and what is our fleet costing us
> when it breaks?

Two questions, two subject areas, no key in common. That is why this track has
two marts and two semantic views rather than one of each. Forcing unrelated
subjects into a single semantic object gives an AI agent a join it cannot make.

## Quickstart

You will need your own Snowflake account and a dbt project pointed at this
repository. No credentials are included here.

1. Clone this repository, or connect it to a dbt project in dbt Studio.
2. `dbt deps`
3. `dbt seed`, which loads `commodity_prices`, `fts_records`, `loglynx` (the
   raw feeds a real deployment would land continuously via Openflow instead)
   plus the small `commodity_reference` lookup.
4. `dbt build --select staging`, which is checkpoint 1 and should be green.
5. `dbt build`, which is where the seeded bugs live. Fix them with dbt Wizard.

Stuck? There's no schema to fall back to any more — the seed is the same for
everyone. Re-clone the repository if you think you've broken something
structural.

## What is in here

```
models/
├── staging/
│   ├── _energy__seeds.yml         seed declarations
│   ├── _energy__models.yml        staging tests and descriptions
│   ├── stg_commodity_prices.sql   typed view, still wide
│   ├── stg_fts_records.sql        field technician maintenance feed
│   └── stg_loglynx.sql            LogLynx maintenance feed
├── intermediate/
│   ├── int_energy_commodity_prices_unpivoted.sql  wide to long
│   └── int_energy_maintenance_logs_unioned.sql    union then de-duplicate
├── marts/
│   ├── _energy__marts.yml
│   ├── energy_commodity_price_history.sql   price fact (contract enforced)
│   ├── energy_maintenance_logs.sql          maintenance fact (contract enforced)
│   ├── energy_maintenance_cost_by_type.sql  strategy rollup (contract enforced)
│   ├── vw_energy_data_quality.sql           data-quality scorecard
│   ├── sv_energy_commodity_prices.sql       Snowflake Semantic View
│   └── sv_energy_equipment_reliability.sql  Snowflake Semantic View
├── semantic/
│   └── README.md                  why the MetricFlow specs live in the marts
│                                  YAML under the latest spec
└── seeds/
    ├── commodity_prices.csv        raw feed: 5,898 daily rows, 23 commodities wide
    ├── fts_records.csv             raw feed: 750 maintenance events
    ├── loglynx.csv                 raw feed: byte-identical mirror of fts_records
    └── commodity_reference.csv     23 commodities: name, group, quoted unit
```

## Read this before you trust a number

`loglynx` is not a second set of maintenance events. It is a mirror of
`fts_records`: all 750 `record_id`s appear in both feeds, and not one row
differs on any column. Two systems are reporting the same physical work,
because a platform migration was started and never finished.

Union the two and stop, and total maintenance cost goes from roughly $410k to
roughly $820k. Nothing errors. Nothing warns you. Every chart looks fine.

`int_energy_maintenance_logs_unioned` unions and then de-duplicates on
`record_id`, with the field technician system as the system of record.
`tests/assert_maintenance_logs_are_deduplicated.sql` is the guard rail, and
`vw_energy_data_quality` reports the overlap as a consistency failure so the
problem stays visible rather than being quietly fixed and forgotten.

## Two other things the data will do to you

**WTI crude goes negative.** On 2020-04-20 the settlement price is -37.63. That
is a real market event, not bad data. There is deliberately no positivity test
on `wti_crude`, and `price_change_pct` divides by `abs(previous_price)` so the
percentage stays meaningful across the sign change.

**The price series ends 2022-11-04.** When you ask Cortex Analyst or the dbt
MCP Server a question, say "in 2022", not "this year". Ask for this year and
you will get a correct and entirely empty answer.

## Headline metrics

Prices: average, highest, lowest and latest price, average daily change,
largest daily gain and loss, trading day count. Sliced by commodity, commodity
group and trade date.

Maintenance: total and average maintenance cost, total and average downtime
hours, average failure rate, cost per downtime hour, completion rate, at-risk
rate, unplanned work rate, analyst hours saved. Sliced by maintenance type and
status, work class, downtime band, equipment, technician and log date.
