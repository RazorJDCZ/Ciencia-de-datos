with expected as (
    select count(*) as expected_rows
    from {{ ref('yellow_taxi_trips') }}
    where is_core_valid
),

actual as (
    select count(*) as actual_rows
    from {{ ref('fct_trips') }}
)

select
    expected_rows,
    actual_rows
from expected
cross join actual
where expected_rows <> actual_rows
