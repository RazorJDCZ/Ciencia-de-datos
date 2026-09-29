select
    trip_id,
    source_period
from {{ ref('yellow_taxi_trips') }}
where not regexp_like(source_period, '^[0-9]{4}-(0[1-9]|1[0-2])$')
