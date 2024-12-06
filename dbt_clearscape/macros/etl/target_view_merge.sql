{# This materisation will create a write view 
 #}
{%- materialization target_view_merge, adapter = "teradata" %}
  {%- set target_relation = this.incorporate() -%}
  {% call statement('main') -%}

  {%- endcall %}
{{ return(target_relation) }}
{% endmaterialization -%}
{# #}