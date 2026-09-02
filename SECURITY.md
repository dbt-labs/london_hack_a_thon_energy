# Security policy

## Reporting a vulnerability

Please do not open a public GitHub issue for security problems.

If you believe you have found a security vulnerability in this repository,
report it privately to **security@dbtlabs.com**. Include:

- A description of the issue and why you believe it is a security problem
- Steps to reproduce, if applicable
- The commit SHA or file path where you found it
- Any suggested remediation

You will receive an acknowledgement of your report. Because this repository is
workshop material rather than a supported product, response and remediation are
best effort — see the support expectations in the [README](README.md).

## Scope

This repository contains a sample dbt project built for a hands-on workshop. It
is intended to run against a warehouse account that you supply. It contains no
credentials.

If you find committed credentials, key material, or anything resembling real
customer or personal data in this repository or its git history, treat that as a
vulnerability and report it using the process above.

## Out of scope

- Deliberate data-quality problems in the seed files. The duplication between
  `fts_records.csv` and `loglynx.csv`, and the negative WTI crude settlement
  price on 2020-04-20, are part of the exercise rather than defects.
- Vulnerabilities in third-party dbt packages listed in `packages.yml`. Report
  those to the relevant package maintainer.
