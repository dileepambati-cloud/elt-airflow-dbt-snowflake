{#
    Fails for rows where column_name > other_column.
    e.g. paid_amount should never be more than billed_amount.

        - name: paid_amount
          data_tests:
            - not_greater_than:
                arguments:
                  other_column: billed_amount
#}
{% test not_greater_than(model, column_name, other_column) %}

select *
from {{ model }}
where {{ column_name }} > {{ other_column }}

{% endtest %}
