with source_data as (
    select
        raw_record,
        source_file,
        source_period,
        loaded_at
    from {{ source('bronze', 'yellow_taxi_raw') }}
),

typed as (
    select
        md5(concat_ws('|', source_period, to_json(raw_record))) as trip_id,
        coalesce(try_to_number(raw_record:"VendorID"::string), 0)::integer as vendor_id,
        try_to_timestamp_ntz(raw_record:"tpep_pickup_datetime"::string) as pickup_datetime,
        try_to_timestamp_ntz(raw_record:"tpep_dropoff_datetime"::string) as dropoff_datetime,
        coalesce(try_to_number(raw_record:"passenger_count"::string), 0)::integer as passenger_count,
        try_to_decimal(raw_record:"trip_distance"::string, 12, 2) as trip_distance,
        coalesce(try_to_number(raw_record:"RatecodeID"::string), 99)::integer as rate_code_id,
        upper(trim(coalesce(raw_record:"store_and_fwd_flag"::string, 'N'))) as store_and_fwd_flag,
        try_to_number(raw_record:"PULocationID"::string)::integer as pickup_location_id,
        try_to_number(raw_record:"DOLocationID"::string)::integer as dropoff_location_id,
        coalesce(try_to_number(raw_record:"payment_type"::string), 5)::integer as payment_type_id,
        try_to_decimal(raw_record:"fare_amount"::string, 12, 2) as fare_amount,
        try_to_decimal(raw_record:"extra"::string, 12, 2) as extra_amount,
        try_to_decimal(raw_record:"mta_tax"::string, 12, 2) as mta_tax,
        try_to_decimal(raw_record:"tip_amount"::string, 12, 2) as tip_amount,
        try_to_decimal(raw_record:"tolls_amount"::string, 12, 2) as tolls_amount,
        try_to_decimal(raw_record:"improvement_surcharge"::string, 12, 2) as improvement_surcharge,
        try_to_decimal(raw_record:"total_amount"::string, 12, 2) as total_amount,
        try_to_decimal(raw_record:"congestion_surcharge"::string, 12, 2) as congestion_surcharge,
        coalesce(
            try_to_decimal(raw_record:"Airport_fee"::string, 12, 2),
            try_to_decimal(raw_record:"airport_fee"::string, 12, 2)
        ) as airport_fee,
        try_to_decimal(raw_record:"cbd_congestion_fee"::string, 12, 2) as cbd_congestion_fee,
        source_file,
        source_period,
        loaded_at
    from source_data
),

valid_records as (
    select
        *,
        datediff('second', pickup_datetime, dropoff_datetime) as trip_duration_seconds
    from typed
    where pickup_datetime is not null
      and dropoff_datetime is not null
      and dropoff_datetime >= pickup_datetime
      and pickup_location_id > 0
      and dropoff_location_id > 0
      and coalesce(trip_distance, 0) >= 0
      and coalesce(total_amount, 0) >= 0
      and passenger_count >= 0
)

select *
from valid_records
qualify row_number() over (
    partition by trip_id
    order by loaded_at desc, source_file desc
) = 1
