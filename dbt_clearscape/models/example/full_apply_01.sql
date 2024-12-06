select DB.databasename 
      ,DB.ownername
      ,BKEY.BKEY_DATABASES_ID
from {{ source('dbc', 'DatabasesV') }} AS DB
INNER JOIN {{ ref('BKEY_DATABASES') }} AS BKEY
ON DB.databasename = BKEY.databasename
SAMPLE 0.9