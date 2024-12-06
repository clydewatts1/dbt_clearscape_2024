{# This materisation will create a write view 
 #}
{%- materialization BKEY, adapter = "teradata" %}
    {%- set target_relation = this.incorporate(type='view') -%}
  -- Set the target relation for this materialization
{# TODO : change name of target relation something about the view >??#}
    {%- set existing_relation = load_cached_relation(this) -%}
-- calling the macro set_query_band() which will set the query_band for this materialization as per the user_configuration
    {% do set_query_band() %}
    {# setup temp trans relationship #}
    {% set temp_trans_schema = config.get('temp_schema')%}
    {% set temp_trans_schema = generate_schema_name(temp_trans_schema) %}
    {% set temp_trans_database = config.get('temp_database') %}
    {% set temp_trans_table = config.get('temp_trans_table',model.name~'_TRANS') %}
    {% set temp_trans_table_relationship = api.Relation.create(schema=temp_trans_schema,database=temp_trans_database,identifier=temp_trans_table,type='table')%}

    {#---- Prehooks --------#}

    {{ run_hooks(pre_hooks, inside_transaction=False) }}

    {{ run_hooks(pre_hooks, inside_transaction=True) }}


-- create a relation shio with the target schema, database and table
{% set x = surrogate_key_create_target_table() %}
{% set x = surrogate_key_create_target_view(target_relation)%}
{% set x = surrogate_key_create_trans_table(temp_trans_table_relationship)%}
{% set x = surrogate_key_populate_trans(temp_trans_table_relationship)%}

{% set surrogate_key_natural_column_list = config.get('surrogate_key_natural_column_list',['NATURAL_KEY'])%}

{% set surrogate_key_domain_column = config.get('surrogate_key_domain_column','DOMAIN_ID') %}
{% set surrogate_key_domain_type = config.get('surrogate_key_domain_type','SMALLINT') %}
{% set surrogate_key_domain_id = config.get('surrogate_key_domain_id','01') %}

{% set surrogate_key_set_column = config.get('surrogate_key_set_column','KEY_SET_ID')%}
{% set surrogate_key_set_type = config.get('surrogate_key_set_type','SMALLINT')%}
{% set surrogate_key_set_id = config.get('surrogate_key_set_id','01')%}

{% set from_tracking_column = config.get('from_tracking_column')%}
{% set to_tracking_column = config.get('to_tracking_column')%}
{% set tracking_high_date = config.get('tracking_high_date')%}
{% set tracking_column_type = config.get('tracking_column_type')%}
{% set logical_delete_column = config.get('logical_delete_column')%}
{% set logical_delete_yes = config.get('logical_delete_yes')%}
{% set logical_delete_no = config.get('logical_delete_no')%}

{% set job_id_column = config.get('job_id_column')%}
{% set run_id_column = config.get('run_id_column')%}
{% set update_prefix = config.get('update_prefix','_UPDATE')%}
{% set job_id_update_column = job_id_column~update_prefix%}
{% set run_id_update_column = run_id_column~update_prefix%}
{%- set columns = adapter.get_columns_in_relation(target_relation) -%}
{% set job_id = config.get('job_id',model.name)%}
{% set surrogate_key_id_column = config.get('surrogate_key_id_column','EDW_KEY')%}
{% call statement('main',auto_begin=true) -%}

LOCK TABLE {{target_relation}} FOR WRITE
;INSERT INTO {{target_relation}}
(

    {% for column in columns -%}
        {{ column.name }}{%- if not loop.last %},{%- endif %}
    {%- endfor -%}
)
SELECT
            ROW_NUMBER() OVER (ORDER BY {%- for row in surrogate_key_natural_column_list %} SRC."{{row}}"{%- if not loop.last %} , {% endif %}{% endfor%})  
            + (SELECT COALESCE(MAX("{{surrogate_key_id_column}}"),0) FROM {{target_relation}})
            
            AS {{ surrogate_key_id_column }}
            {%- for row in surrogate_key_natural_column_list %}
           ,SRC."{{ row }}" AS "{{ row }}"
            {%- endfor %}
            {%- if surrogate_key_domain_column is defined %}
           ,{{ surrogate_key_domain_id }} AS {{ surrogate_key_domain_column }} 
            {%- endif %}
            {%- if surrogate_key_set_column is defined %}
           ,{{ surrogate_key_set_id }} AS {{ surrogate_key_set_column }} 
            {%- endif %}
           ,CURRENT_DATE AS {{ from_tracking_column }} 
           ,{{tracking_high_date}} AS {{ to_tracking_column }} 
           ,{{logical_delete_no}} as {{ logical_delete_column }} 
           {%- if job_id_column is defined %}
           ,'{{job_id}}' AS {{ job_id_column }}
           ,NULL AS {{ job_id_update_column }} 
           {%- endif %}
           {%- if run_id_column is defined %}
           ,'{{invocation_id}}' AS {{ run_id_column }} 
           ,NULL AS {{ run_id_update_column }} 
           {%- endif %}

FROM {{temp_trans_table_relationship}} AS SRC
LEFT OUTER JOIN {{target_relation}} AS TGT
ON 
{%- for row in surrogate_key_natural_column_list %}
TGT.{{ row }} = SRC.{{ row }}{%- if not loop.last %} AND {% endif %}
{%- endfor %}
WHERE TGT.{{ surrogate_key_id_column }} IS NULL
{%- endcall %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {% do adapter.commit() %}

  {% for rel in to_drop %}
      {% do adapter.drop_relation(rel) %}
  {% endfor %}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

{{ return({'relations': [target_relation]}) }}
{% endmaterialization -%}

{#------------------------------------------------------------------------------------------------
-- Macro: surrogate_key_create_target_table
-- Description: This will create the surrogate key target table
-- The table is independent of the "sql" passed in
--------------------------------------------------------------------------------------------------

#}
{% macro surrogate_key_create_target_table() -%}
    {% do log(sql)%}
    {# Get schema , database and identify for surrogate key table #}
    {% set surrogate_key_target_schema = config.get('surrogate_key_target_schema') %}
    {# convert to full schema #}
    {% set surrogate_key_target_schema = generate_schema_name(surrogate_key_target_schema) %}
    {% set surrogate_key_target_database = config.get('surrogate_key_target_database') %}
    {% set surrogate_key_target_table = config.get('surrogate_key_target_table') %}
    {% set surrogate_key_target_relationship = api.Relation.create(schema=surrogate_key_target_schema,database=surrogate_key_target_database,identifier=surrogate_key_target_table,type='table')%}
    {# Check if table exists , ignore the rest if table exists#}
    {% do log("surrogate_key_target_relationship="~surrogate_key_target_relationship)%}
    {%- set surrogate_key_target_relationship_db = adapter.get_relation(database=surrogate_key_target_relationship.database
            ,schema=surrogate_key_target_relationship.schema
            ,identifier=surrogate_key_target_relationship.identifier) -%} 
    {% if surrogate_key_target_relationship_db is not none %}
        {% do log("SURROGATE KEY target table exists : ")%}
    {% else %}
        {# Now start building table#}
        {% do log("BEGIN TO CREATE SURROGATE KEY TABLE :  "~surrogate_key_target_relationship)%}
        {# Set up variables from config #}
        {# TOOO : change required #}
        {% set from_tracking_column = config.get('from_tracking_column')%}
        {% set to_tracking_column = config.get('to_tracking_column')%}
        {% set tracking_column_type = config.get('tracking_column_type')%}
        {% set logical_delete_column = config.get('logical_delete_column')%}
        {% set logical_delete_type = config.get('logical_delete_type')%}
        {% set job_id_column = config.get('job_id_column')%}
        {% set run_id_column = config.get('run_id_column')%}
        {% set job_id_column_type = config.get('job_id_column_type','VARCHAR(128)')%}
        {% set run_id_column_type = config.get('job_id_column_type','VARCHAR(128)')%}
        {% set update_prefix = config.get('update_prefix','_UPDATE')%}
        {% set job_id_update_column = job_id_column~update_prefix%}
        {% set run_id_update_column = run_id_column~update_prefix%}
        {% set surrogate_key_id_column = config.get('surrogate_key_id_column','EDW_KEY')%}
        {% set surrogage_key_id_type   = config.get('surrogage_key_id_type','BIGINT')%}
        {% set surrogate_key_natural_column_list = config.get('surrogate_key_natural_column_list',['NATURAL_KEY'])%}
        {% set surrogate_key_table_seperator = config.get('surrogate_key_table_seperator','_')%}
        {% set surrogate_key_natural_column_type = config.get('surrogate_key_natural_column_type','VARCHAR(255)')%}
        {% set surrogate_key_domain_column = config.get('surrogate_key_domain_column','DOMAIN_ID')%}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type','SMALLINT') %}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type')%}
        {% set job_id = config.get('job_id',model.name)%}
        {# Now start building the create table string #}
        {% set index = config.get('index','UNIQUE PRIMARY INDEX("'~surrogate_key_id_column~'")')%}
        {% set surrogate_key_domain_column = config.get('surrogate_key_domain_column','DOMAIN_ID') %}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type','SMALLINT') %}
        {% set surrogate_key_domain_id = config.get('surrogate_key_domain_id','01') %}

        {% set surrogate_key_set_column = config.get('surrogate_key_set_column','KEY_SET_ID')%}
        {% set surrogate_key_set_type = config.get('surrogate_key_set_type','SMALLINT')%}
        {% set surrogate_key_set_id = config.get('surrogate_key_set_id','01')%}


        {% set sql_create_table%}
        CREATE TABLE {{surrogate_key_target_relationship}}
        (
            {{ surrogate_key_id_column }} {{ surrogage_key_id_type }} NOT NULL
            {%- for row in surrogate_key_natural_column_list %}
           ,{{ row }} {{ surrogate_key_natural_column_type[loop.index0] }} NOT NULL
            {%- endfor %}
            {%- if surrogate_key_domain_column is defined %}
           ,{{ surrogate_key_domain_column }} {{ surrogate_key_domain_type }} NOT NULL COMPRESS({{ surrogate_key_domain_id }})
            {%- endif %}
            {%- if surrogate_key_set_column is defined %}
           ,{{ surrogate_key_set_column }} {{ surrogate_key_set_type }} NOT NULL COMPRESS({{ surrogate_key_set_id }})
            {%- endif %}
           ,{{ from_tracking_column }} {{ tracking_column_type }} NOT NULL
           ,{{ to_tracking_column }} {{ tracking_column_type }} NOT NULL
           ,{{ logical_delete_column }} {{ logical_delete_type }} NOT NULL
           {%- if job_id_column is defined %}
           ,{{ job_id_column }} {{ job_id_column_type }} NOT NULL COMPRESS('')
           ,{{ job_id_update_column }} {{ job_id_column_type }}  COMPRESS(NULL)
           {%- endif %}
           {%- if run_id_column is defined %}
           ,{{ run_id_column }} {{ run_id_column_type }} NOT NULL
           ,{{ run_id_update_column }} {{ run_id_column_type }} COMPRESS(NULL)
           {%- endif %}
        ) {{index}}
     {% endset %}
        {# Log the create table string #}
        {% do log("sql_create_table"~sql_create_table)%}
        {# Execute the create table string #}
        {% set results = run_query(sql_create_table) %}
        {# Log results #}
        {% do log("results"~results)%}
        {# Log the create table string #}
        {% do log("END CREATE SURROGATE KEY TABLE :  "~surrogate_key_target_relationship)%}
    
        ----- =============================================== ---
    {% endif %}

    {{ return(target_relation) }}
{% endmacro -%}


 
{#------------------------------------------------------------------------------------------------
-- Macro: surrogate_key_create_target_view
-- Description: This will create the surrogate key view table
-- The table is independent of the "sql" passed in
--------------------------------------------------------------------------------------------------

#}
{% macro surrogate_key_create_target_view(target_relation) -%}
    {% do log("Create surroge key view :"~target_relation) %}
    {% do log(sql)%}
    {# Get schema , database and identify for surrogate key table #}
    {% set surrogate_key_target_schema = config.get('surrogate_key_target_schema') %}
    {# convert to full schema #}
    {% set surrogate_key_target_schema = generate_schema_name(surrogate_key_target_schema) %}
    {% set surrogate_key_target_database = config.get('surrogate_key_target_database') %}
    {% set surrogate_key_target_table = config.get('surrogate_key_target_table') %}
    {% set surrogate_key_target_relationship = api.Relation.create(schema=surrogate_key_target_schema,database=surrogate_key_target_database,identifier=surrogate_key_target_table,type='table')%}
    {# Check if table exists , ignore the rest if table exists#}
    {% do log("surrogate_key_target_relationship="~surrogate_key_target_relationship)%}
  {%- set surrogate_key_view_relationship_db = adapter.get_relation(database=target_relation.database
            ,schema=target_relation.schema
            ,identifier=target_relation.identifier) -%} 
    {% if surrogate_key_view_relationship_db is not none %}
        {% do log("SURROGATE KEY target view exists : "~surrogate_key_view_relationship_db)%}
    {% else %}
        {# Now start building table #}
        {% do log("BEGIN TO CREATE SURROGATE KEY VIEW :  "~surrogate_key_target_relationship)%}
        {# Get columns from target surrogate_key_target_relationship #}
        {%- set view_columns = adapter.get_columns_in_relation(surrogate_key_target_relationship) -%}

        {% set sql_view_table%}
        REPLACE vIEW {{target_relation}} AS 
            SELECT
            {%- for row in view_columns %}
            {{ row.name }} 
            {%- if not loop.last %} 
            , 
            {%- endif %}
            {%- endfor %}
            FROM {{surrogate_key_target_relationship}}
        
    {% endset %}
        {# Log the create table string #}
        {% do log("sql_view_table"~sql_view_table)%}
        {# Execute the create table string #}
        {% set results = run_query(sql_view_table) %}
        {# Log results #}
        {% do log("results"~results)%}
        {# Log the create table string #}
        {% do log("END CREATE SURROGATE KEY VIEW :  "~surrogate_key_target_relationship)%}
        ----- =============================================== ---
    {% endif %}

    {{ return(target_relation) }}
{% endmacro -%}


 
{#------------------------------------------------------------------------------------------------
-- Macro: surrogate_key_create_trans_table
-- Description: This will create the surrogate key target table
-- The table is independent of the "sql" passed in
--------------------------------------------------------------------------------------------------

#}
{% macro surrogate_key_create_trans_table(temp_trans_table_relationship) -%}
    {% do log(sql)%}
    {# Get schema , database and identify for surrogate key table #}
     {# Check if table exists , ignore the rest if table exists#}
    {% do log("temp_trans_table_relationship="~temp_trans_table_relationship)%}
    {%- set temp_trans_table_relationship_db = 
    adapter.get_relation(database=temp_trans_table_relationship.database
            ,schema=temp_trans_table_relationship.schema
            ,identifier=temp_trans_table_relationship.identifier) -%} 
    {% if temp_trans_table_relationship_db is not none %}
        {% do log("SURROGATE KEY trans table exists : ")%}
    {% else %}
        {# Now start building table#}
        {% do log("BEGIN TO CREATE SURROGATE KEY TRANS TABLE :  "~temp_trans_table_relationship)%}
        {# Set up variables from config #}
        {# TOOO : change required #}
        {% set surrogate_key_id_column = config.get('surrogate_key_id_column','EDW_KEY')%}
        {% set surrogage_key_id_type   = config.get('surrogage_key_id_type','BIGINT')%}
        {% set surrogate_key_natural_column_list = config.get('surrogate_key_natural_column_list',['NATURAL_KEY'])%}
        {% set surrogate_key_table_seperator = config.get('surrogate_key_table_seperator','_')%}
        {% set surrogate_key_natural_column_type = config.get('surrogate_key_natural_column_type','VARCHAR(255)')%}
        {% set surrogate_key_domain_column = config.get('surrogate_key_domain_column','DOMAIN_ID')%}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type','SMALLINT') %}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type')%}
        {# Now start building the create table string #}
        {% set index = config.get('index')%}
        {# if index is None or underfined then base surrogate key on surrogate_key_natural_column_list using for loop and ignoring
          last comma#}
        {% if index is none or index is undefined %}
            {% set index %}
             PRIMARY INDEX(
            {%- for row in surrogate_key_natural_column_list %}
                {{ row }}{%- if not loop.last %},{%- endif %}
            {%- endfor %}
            )
            {% endset %}
        {% endif %}

        {% set surrogate_key_domain_column = config.get('surrogate_key_domain_column','DOMAIN_ID') %}
        {% set surrogate_key_domain_type = config.get('surrogate_key_domain_type','SMALLINT') %}
        {% set surrogate_key_domain_id = config.get('surrogate_key_domain_id','01') %}

        {% set surrogate_key_set_column = config.get('surrogate_key_set_column','KEY_SET_ID')%}
        {% set surrogate_key_set_type = config.get('surrogate_key_set_type','SMALLINT')%}
        {% set surrogate_key_set_id = config.get('surrogate_key_set_id','01')%}


        {% set sql_create_table%}
        CREATE TABLE {{temp_trans_table_relationship}}
        (
            {%- for row in surrogate_key_natural_column_list %}
                {{ row }} {{ surrogate_key_natural_column_type[loop.index0] }} NOT NULL{%- if not loop.last %},{%- endif %}
            {%- endfor %}
         ) {{index}}
     {% endset %}
        {# Log the create table string #}
        {% do log("sql_create_table"~sql_create_table)%}
        {# Execute the create table string #}
        {% set results = run_query(sql_create_table) %}
        {# Log results #}
        {# do log("results"~results)#}
        {# Log the create table string #}
        {% do log("END CREATE SURROGATE KEY TABLE :  "~surrogate_key_target_relationship)%}
    
        ----- =============================================== ---
    {% endif %}

    {{ return(target_relation) }}
{% endmacro -%}


{% macro surrogate_key_populate_trans(temp_trans_table_relationship) -%}
    {% do log(sql)%}
    {# delete from trans table #}
    {% set sql_delete%}
    DELETE FROM {{temp_trans_table_relationship}}
    {% endset %}
    {# Log the create table string #}
    {% do log("sql_delete"~sql_delete)%}
    {# insert "SQL" into trans table #}
    {% set sql_insert%}
    INSERT
    INTO {{temp_trans_table_relationship}}
    {{sql}}
    {% endset %}
    {# Log the create table string #}
    {% do log("sql_insert"~sql_insert)%}
    {# Execute the create table string #}
    {% set results = run_query(sql_delete) %}
    {# Log results #}
    {% do log("results"~results)%}
    {# Execute the create table string #}
    {% set results = run_query(sql_insert) %}
    {# Log results #}
    {% do log("results"~results)%}
    {{ return(target_relation) }}


{% endmacro -%}
 
