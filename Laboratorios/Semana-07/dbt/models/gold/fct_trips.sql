{{
    config(
        cluster_by=["source_period", "to_date(pickup_datetime)"]
    )
}}

select
    trip_id as trip_key,
    vendor_id as vendor_key,
    rate_code_id as rate_code_key,
    payment_type_id as payment_type_key,
    pickup_location_id as pickup_location_key,
    dropoff_location_id as dropoff_location_key,
    to_number(to_char(pickup_datetime::date, 'YYYYMMDD')) as pickup_date_key,
    to_number(to_char(dropoff_datetime::date, 'YYYYMMDD')) as dropoff_date_key,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    trip_duration_seconds,
    round(trip_duration_seconds / 60.0, 2) as trip_duration_minutes,
    case
        when trip_duration_seconds > 0 and trip_distance >= 0
            then round(trip_distance / (trip_duration_seconds / 3600.0), 2)
    end as average_speed_mph,
    fare_amount,
    extra_amount,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    store_and_fwd_flag,
    quality_status,
    is_analytically_valid,
    is_financial_adjustment,
    is_missing_passenger_count,
    is_extreme_duration,
    is_zero_distance,
    is_zero_total,
    is_source_period_mismatch,
    source_period,
    source_file,
    loaded_at
from {{ ref('yellow_taxi_trips') }}
where is_core_valid
