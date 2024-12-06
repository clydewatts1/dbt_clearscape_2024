select DB.databasename 
      ,DB.ownername
from {{ source('dbc', 'DatabasesV') }} AS DB
INNER JOIN {{ ref('BKEY_DATABASES') }} AS BKEY
ON DB.databasename = BKEY.databasename
SAMPLE 0.9