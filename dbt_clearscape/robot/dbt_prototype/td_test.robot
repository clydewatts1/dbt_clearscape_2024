*** Settings ***
Library       DatabaseLibrary
Test Setup    Connect To My Oracle DB

*** Keywords ***
Connect To My Oracle DB
    Connect To Database
    ...    teradatasql
    ...    db_name=dbc
    ...    db_user=demo_user
    ...    db_password=Achill853
    ...    db_host=dbtclearscape-vjpiuc437tcyfda4.env.clearscape.teradata.com

*** Test Cases ***
Get All Names
    ${Rows}=    Query    select databasename from dbc.databasesv where databasename='dbc'
    Should Be Equal    ${Rows}[0][0]    DBC
