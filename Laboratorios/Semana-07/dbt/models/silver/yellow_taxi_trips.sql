{{
    config(
        cluster_by=["source_period", "to_date(pickup_datetime)"]
    )
}}

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
        try_to_number(raw_record:"passenger_count"::string)::integer as passenger_count,
        try_to_decimal(raw_record:"trip_distance"::string, 12, 2) as trip_distance,
        coalesce(try_to_number(raw_record:"RatecodeID"::string), 99)::integer as rate_code_id,
        case
            when upper(trim(raw_record:"store_and_fwd_flag"::string)) in ('Y', 'N')
                then upper(trim(raw_record:"store_and_fwd_flag"::string))
            else 'U'
        end as store_and_fwd_flag,
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

deduplicated as (
    select *
    from typed
    qualify row_number() over (
        partition by trip_id
        order by loaded_at desc, source_file desc
    ) = 1
),

enriched as (
    select
        *,
        datediff('second', pickup_datetime, dropoff_datetime) as trip_duration_seconds,
        passenger_count is null as is_missing_passenger_count,
        trip_distance is null as is_missing_trip_distance,
        total_amount is null as is_missing_total_amount,
        coalesce(total_amount < 0 or fare_amount < 0, false) as is_financial_adjustment,
        coalesce(trip_distance = 0, false) as is_zero_distance,
        coalesce(total_amount = 0, false) as is_zero_total,
        coalesce(
            to_char(pickup_datetime, 'YYYY-MM') <> source_period,
            false
        ) as is_source_period_mismatch
    from deduplicated
),

classified as (
    select
        *,
        coalesce(trip_duration_seconds > 86400, false) as is_extreme_duration,
        case
            when pickup_datetime is null or dropoff_datetime is null
                then 'INVALID_DATETIME'
            when dropoff_datetime < pickup_datetime
                then 'NEGATIVE_DURATION'
            when pickup_location_id is null or pickup_location_id <= 0
              or dropoff_location_id is null or dropoff_location_id <= 0
                then 'INVALID_LOCATION'
            when trip_distance is null
                then 'MISSING_DISTANCE'
            when trip_distance < 0
                then 'NEGATIVE_DISTANCE'
            when passenger_count < 0
                then 'NEGATIVE_PASSENGER_COUNT'
            else 'VALID'
        end as core_quality_status
    from enriched
)

select
    *,
    core_quality_status = 'VALID' as is_core_valid,
    core_quality_status = 'VALID'
        and not is_financial_adjustment
        and not is_missing_total_amount as is_analytically_valid,
    case
        when core_quality_status <> 'VALID' then 'INVALID'
        when is_financial_adjustment
          or is_missing_passenger_count
          or is_missing_total_amount
          or is_extreme_duration
          or is_zero_distance
          or is_zero_total
          or is_source_period_mismatch
          or store_and_fwd_flag = 'U'
            then 'VALID_WITH_WARNINGS'
        else 'VALID'
    end as quality_status
from classified
