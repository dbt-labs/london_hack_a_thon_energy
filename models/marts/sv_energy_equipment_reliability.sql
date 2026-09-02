-- ---------------------------------------------------------------------------
-- sv_energy_equipment_reliability
--
-- A Snowflake Semantic View over the de-duplicated maintenance fact.
--
-- This is the second of the energy track's two semantic views. Commodity
-- prices and equipment maintenance share no key, so they get one object each.
--
-- Worth saying out loud when you demo this: every number here is computed on
-- de-duplicated events. If the union upstream had not been de-duplicated, this
-- semantic view would answer every question with exactly double the truth, and
-- Cortex Analyst would have no way to know. The semantic layer is only as
-- trustworthy as the model underneath it.
-- ---------------------------------------------------------------------------

{{ config(materialized='semantic_view') }}

TABLES (

    maintenance AS {{ ref('energy_maintenance_logs') }}
        PRIMARY KEY (maintenance_log_id)
        WITH SYNONYMS = ('maintenance', 'work orders', 'service events', 'repairs')
        COMMENT = 'One row per maintenance event on the equipment fleet, de-duplicated across two source systems.'

)

FACTS (

    maintenance.event_cost AS maintenance.maintenance_cost
        COMMENT = 'Cost of the maintenance event in USD.',

    maintenance.event_downtime AS maintenance.downtime_hours
        COMMENT = 'Hours the asset was unavailable for this event.',

    maintenance.event_failure_rate AS maintenance.failure_rate
        COMMENT = 'Observed failure rate for the asset, 0 to 1.',

    maintenance.event_cost_per_hour AS maintenance.cost_per_downtime_hour
        COMMENT = 'Maintenance cost divided by hours of downtime.',

    maintenance.analyst_hours_saved AS maintenance.summarization_hours_saved
        COMMENT = 'Analyst hours saved by the AI summary of the technician log.',

    maintenance.completed_flag AS CASE WHEN maintenance.is_completed THEN 1 ELSE 0 END
        COMMENT = 'One when the maintenance event is complete, otherwise zero.',

    maintenance.at_risk_flag AS CASE WHEN maintenance.is_at_risk THEN 1 ELSE 0 END
        COMMENT = 'One when the event is delayed or cancelled, otherwise zero.',

    maintenance.unplanned_flag AS CASE WHEN maintenance.work_class = 'Unplanned' THEN 1 ELSE 0 END
        COMMENT = 'One when the event was corrective, meaning something broke.'

)

DIMENSIONS (

    maintenance.log_date AS maintenance.log_date
        WITH SYNONYMS = ('date', 'when', 'maintenance date', 'service date')
        COMMENT = 'Date of the maintenance event. The series runs 2024-06-27 to 2026-07-16.',

    maintenance.equipment_id AS maintenance.equipment_id
        WITH SYNONYMS = ('equipment', 'asset', 'machine', 'unit')
        COMMENT = 'Identifier of the asset the work was done on.',

    maintenance.technician_id AS maintenance.technician_id
        WITH SYNONYMS = ('technician', 'engineer', 'who did the work')
        COMMENT = 'Identifier of the technician who performed the work.',

    maintenance.customer_id AS maintenance.customer_id
        WITH SYNONYMS = ('customer', 'account', 'site owner')
        COMMENT = 'Customer the asset belongs to.',

    maintenance.maintenance_type AS maintenance.maintenance_type
        WITH SYNONYMS = ('maintenance type', 'strategy', 'type of work')
        COMMENT = 'Preventive, Predictive, Corrective, Condition-Based or Reliability-Centered Maintenance.',

    maintenance.maintenance_status AS maintenance.maintenance_status
        WITH SYNONYMS = ('status', 'state', 'progress')
        COMMENT = 'Completed, In Progress, Scheduled, Delayed or Cancelled.',

    maintenance.work_class AS maintenance.work_class
        WITH SYNONYMS = ('planned or unplanned', 'work class', 'planned work')
        COMMENT = 'Planned or Unplanned. Corrective work is unplanned; everything else is planned.',

    maintenance.downtime_band AS maintenance.downtime_band
        WITH SYNONYMS = ('downtime band', 'severity', 'how disruptive')
        COMMENT = 'Major (8 hours or more), Moderate (4 to 8) or Minor (under 4).',

    maintenance.source_system AS maintenance.source_system
        WITH SYNONYMS = ('source system', 'feed', 'which system')
        COMMENT = 'Which source feed the surviving record came from after de-duplication.'

)

METRICS (

    maintenance.total_maintenance_cost AS SUM(maintenance.event_cost)
        WITH SYNONYMS = ('total cost', 'maintenance spend', 'total maintenance cost')
        COMMENT = 'Total maintenance spend in USD.',

    maintenance.average_maintenance_cost AS AVG(maintenance.event_cost)
        WITH SYNONYMS = ('average cost', 'cost per event', 'typical cost')
        COMMENT = 'Average cost of a maintenance event in USD.',

    maintenance.total_downtime_hours AS SUM(maintenance.event_downtime)
        WITH SYNONYMS = ('total downtime', 'hours down', 'lost hours')
        COMMENT = 'Total hours of equipment downtime.',

    maintenance.average_downtime_hours AS AVG(maintenance.event_downtime)
        WITH SYNONYMS = ('average downtime', 'typical downtime', 'mean time to repair')
        COMMENT = 'Average hours of downtime per maintenance event.',

    maintenance.average_failure_rate AS AVG(maintenance.event_failure_rate)
        WITH SYNONYMS = ('failure rate', 'average failure rate', 'reliability')
        COMMENT = 'Average observed failure rate, 0 to 1. Lower is better.',

    maintenance.cost_per_downtime_hour AS SUM(maintenance.event_cost) / NULLIF(SUM(maintenance.event_downtime), 0)
        WITH SYNONYMS = ('cost per hour of downtime', 'downtime cost rate')
        COMMENT = 'Total maintenance cost divided by total downtime hours.',

    maintenance.event_count AS COUNT(maintenance.maintenance_log_id)
        WITH SYNONYMS = ('number of events', 'work orders', 'how many jobs')
        COMMENT = 'Number of maintenance events.',

    maintenance.completion_rate AS SUM(maintenance.completed_flag) / NULLIF(COUNT(maintenance.maintenance_log_id), 0)
        WITH SYNONYMS = ('completion rate', 'share completed', 'how much is done')
        COMMENT = 'Share of maintenance events marked Completed, 0 to 1.',

    maintenance.at_risk_rate AS SUM(maintenance.at_risk_flag) / NULLIF(COUNT(maintenance.maintenance_log_id), 0)
        WITH SYNONYMS = ('at risk rate', 'delayed or cancelled rate', 'slippage')
        COMMENT = 'Share of maintenance events delayed or cancelled, 0 to 1.',

    maintenance.unplanned_work_rate AS SUM(maintenance.unplanned_flag) / NULLIF(COUNT(maintenance.maintenance_log_id), 0)
        WITH SYNONYMS = ('unplanned work rate', 'reactive maintenance share', 'breakdown rate')
        COMMENT = 'Share of maintenance events that were corrective, 0 to 1. The headline reliability KPI.',

    maintenance.total_analyst_hours_saved AS SUM(maintenance.analyst_hours_saved)
        WITH SYNONYMS = ('hours saved', 'time saved by AI', 'summarisation savings')
        COMMENT = 'Total analyst hours saved by AI summarisation of technician logs.'

)

COMMENT = 'Equipment reliability and maintenance economics for the energy track of the Openflow, Snowflake and dbt hands-on lab.'
