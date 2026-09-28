with dates as (
    select pickup_datetime::date as calendar_date
    from {{ ref('yellow_taxi_trips') }}
    union
    select dropoff_datetime::date as calendar_date
    from {{ ref('yellow_taxi_trips') }}
)

select
    to_number(to_char(calendar_date, 'YYYYMMDD')) as date_key,
    calendar_date,
    year(calendar_date) as year,
    quarter(calendar_date) as quarter,
    month(calendar_date) as month,
    monthname(calendar_date) as month_name,
    day(calendar_date) as day_of_month,
    dayofweekiso(calendar_date) as day_of_week,
    dayname(calendar_date) as day_name,
    iff(dayofweekiso(calendar_date) in (6, 7), true, false) as is_weekend
from dates
where calendar_date is not null
