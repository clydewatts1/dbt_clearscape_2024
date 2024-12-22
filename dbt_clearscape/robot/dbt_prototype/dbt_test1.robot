*** Settings ***
Documentation     This .robot file is a suite
...
...               Keywords are imported from the resource file
Library           DateTime
Library           OperatingSystem
Library           Process
Library           Collections
Library           DatabaseLibrary
Resource          C:\\Users\\cw171001\\OneDrive - Teradata\\Documents\\dbt_clearscape\\dbt_clearscape\\dbt_clearscape\\robot\\resources\\dbt_core.resource
Test Setup    Connect To My Teradata DB


*** Variables ***


*** Keywords ***
Connect To My Teradata DB
    Connect To Database
    ...    teradatasql
    ...    db_name=dbc
    ...    db_user=demo_user
    ...    db_password=Achill853
    ...    db_host=dbtclearscape-vjpiuc437tcyfda4.env.clearscape.teradata.com

Get DBT Info
    [Documentation]    This will get the DBT info
    ${Rows}=    Query    select * from dbc.dbcinfo



*** Test Cases ***

Test DBT Version
    [Documentation]    Tests if the DBT version is correct
    dbt_core.DBT Version Test    1.9.0

Test Teradata Connection
    [Documentation]    Tests if the Teradata connection is successful
    Connect To My Teradata DB
    Get DBT Info

Prepare Tables for Testing
    [Documentation]    This will delete the target Tables
    Execute Sql String    DELETE FROM CS01_TARGET.BKEY_DATABASES
    Execute Sql String    DELETE FROM CS01_TARGET.full_apply_database
    

Run Model BKEY_01_03_01
    [Documentation]    This will test the running of the surrogate key model
    DBT Run  BKEY_01_03_01

Run Model Full Apply 01
    [Documentation]    This will test the running of the full apply model No 1
    DBT Run  Full_Apply_01 

Run Model Full Apply 02
    [Documentation]    This will test the running of the full apply model No 2
    DBT Run  Full_Apply_02

Run Model Target Table Databases
    [Documentation]    This will test the running of the target table databases model
    DBT Run  Target_Table_Databases

 
Check that the tables are populates
    [Documentation]    This will check that the tables are populated
    # Get the row count of the tables
    ${Row_Count}  Query    select count(*) from CS01_TARGET.BKEY_DATABASES
    # Check that the row count is greater than 0
    Should Be True    ${Row_Count[0][0]} > 0    
    ${Row_Count}  Query    select count(*) from CS01_TARGET.full_apply_database
    Should Be True    ${Row_Count[0][0]} > 0
