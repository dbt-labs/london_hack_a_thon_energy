# dbt Semantic Layer definitions for the energy track

**The definitions are not in this folder. They are in
[`../marts/_energy__marts.yml`](../marts/_energy__marts.yml).**

That is not an accident, and it is worth understanding.

## Why they moved

The dbt Semantic Layer used to be declared with top-level `semantic_models:`
and `metrics:` keys in their own file, which is what this folder was for. The
latest spec, which the Fusion engine requires, embeds the semantic annotations
directly in the model they describe:

| | Legacy spec | Latest spec (what this project uses) |
|---|---|---|
| Semantic model | top-level `semantic_models:` with `model: ref(...)` | `semantic_model: {enabled: true}` under the model |
| Entities and dimensions | separate `entities:` and `dimensions:` lists | `entity:` and `dimension:` on the column itself |
| Measures | `measures:` list, then a metric wrapping each one | gone; a simple metric with `agg:` and `expr:` |
| Metric parameters | nested under `type_params:` | promoted to top-level keys |

A dbt model can only be configured in one YAML file, so once the semantic
annotations attach to columns, they have to live beside the contract. Running
`dbt parse` on the legacy version emits
`SemanticModelDeprecated (dbt1157)`.

There is a real benefit to the new shape. The column's data type, its contract
entry, its tests, its description and its role in the semantic layer are now
one block you read top to bottom, instead of the same column being described in
two files that drift apart.

## What to read

- **[`../marts/_energy__marts.yml`](../marts/_energy__marts.yml)** for the metrics, entities and
  dimensions. Look for the `semantic_model:` and `metrics:` blocks under each
  mart.
- **[`../marts/`](../marts/)** for sv_energy_commodity_prices.sql and sv_energy_equipment_reliability.sql, the Snowflake Semantic View,
  which is the other way this track defines meaning.

## What still belongs in this folder

Top-level `metrics:` are still valid in a standalone file, and that is the
right home for a metric that spans more than one model. This track does not
have one yet. If you add one, put it here as `energy.yml`.

## Migrating a track you wrote against the old spec

```bash
uvx dbt-autofix deprecations --semantic-layer
```

It folds measures into simple metrics and moves everything onto the model.
Check the diff afterwards: it concatenates descriptions and can displace
comment blocks.
