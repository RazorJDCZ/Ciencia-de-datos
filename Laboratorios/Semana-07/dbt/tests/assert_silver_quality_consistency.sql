select
    trip_id,
    core_quality_status,
    quality_status,
    is_core_valid,
    is_analytically_valid,
    is_financial_adjustment,
    is_missing_total_amount
from {{ ref('yellow_taxi_trips') }}
where is_core_valid <> (core_quality_status = 'VALID')
   or is_analytically_valid <> (
        core_quality_status = 'VALID'
        and not is_financial_adjustment
        and not is_missing_total_amount
   )
   or (quality_status = 'INVALID' and is_core_valid)
   or (quality_status <> 'INVALID' and not is_core_valid)
