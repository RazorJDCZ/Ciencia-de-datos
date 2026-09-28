with trip_locations as (
    select pickup_location_id as location_id
    from {{ ref('yellow_taxi_trips') }}
    union
    select dropoff_location_id as location_id
    from {{ ref('yellow_taxi_trips') }}
),

zones as (
    select
        location_id::integer as location_id,
        borough,
        zone,
        service_zone
    from {{ source('bronze', 'taxi_zone_lookup_raw') }}
    qualify row_number() over (
        partition by location_id
        order by loaded_at desc
    ) = 1
)

select
    l.location_id as location_key,
    coalesce(z.borough, 'Unknown') as borough,
    coalesce(z.zone, 'Unknown') as zone,
    coalesce(z.service_zone, 'Unknown') as service_zone
from trip_locations l
left join zones z using (location_id)
