{# This materisation will create a write view 
 #}
{%- materialization table_alpha, adapter = "teradata" %}
{%- set target_relation = this.incorporate(type='table') -%}
  {% set create_sql = teradata_tbl_alpha_generate_create_statement(target_relation)%}
  {% do log("MODEL_COLUMNS:"~model.columns)%}
  {% do log("create_sql"~create_sql)%}
  {% call statement('main') -%}

  {%- endcall %}
{{ return({'relations': [target_relation]}) }}
{% endmaterialization -%}
{# #}

{# Macro to generate the create statement for the table #}
{% macro teradata_tbl_alpha_generate_create_statement(rel)%}

    {% set table_kind = config.get('table_kind','SET')%}
    {% set table_option = config.get('table_option','')%}
    {% set index = config.get('index','NO PRIMARY INDEX')%}
    {% set create_ddl %}

    CREATE {{ table_kind }}  TABLE {{ rel.schema }}.{{ rel.name }} 
  {{ table_option }}
(
  {% for column in rel.columns %}
    {{ column.name }} {{ column.data_type }} {{ "," if not loop.last }}
  {% endfor %}
)

{% endset%}
{% do log("CREATE_SQL<<"~create_ddl)%}

return(create_ddl)
{% endmacro -%}

