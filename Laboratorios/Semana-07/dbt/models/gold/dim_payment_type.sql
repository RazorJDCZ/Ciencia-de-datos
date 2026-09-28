select distinct
    payment_type_id as payment_type_key,
    case payment_type_id
        when 1 then 'Credit card'
        when 2 then 'Cash'
        when 3 then 'No charge'
        when 4 then 'Dispute'
        when 5 then 'Unknown'
        when 6 then 'Voided trip'
        else 'Unknown'
    end as payment_type_name
from {{ ref('yellow_taxi_trips') }}
