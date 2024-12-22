*** Settings ***
Library           DateTime
Library           OperatingSystem
Library           Process
Library           Collections

*** Variables ***
${DBT_EXEC}        C:\\Users\\cw171001\\OneDrive - Teradata\\Documents\\dbt_clearscape\\dbt_clearscape\\dbt-env\\Scripts\\dbt.exe
${DBT_PROJECT_DIR}    C:\\Users\\cw171001\\OneDrive - Teradata\\Documents\\dbt_clearscape\\dbt_clearscape\\dbt_prototype
${DBT_LOG_LEVEL}    info
${DBT_LOG_PATH}    C:\\Users\\cw171001\\OneDrive - Teradata\\Documents\\dbt_clearscape\\dbt_clearscape\\dbt_prototype\\logs
${DBT_PROFILE}    C:\Users\cw171001\.dbt\profiles.yml

*** Keywords ***

DBT Version Test
    [Documentation]    Tests if the DBT version is correct
    [Arguments]    ${expected_version}
    ${dbt_version}=    Run Process     ${DBT_EXEC}  --version
    Log    ${dbt_version.stdout}
    Log    ${DBT_PROFILE}
    Should Contain    ${dbt_version.stdout}   ${expected_version}

DBT Test
    [Documentation]    Tests if the DBT run is successful
    [Arguments]    ${selected_project}
    ${dbt_run}=    Run Process     ${DBT_EXEC}  test  --log-level  ${DBT_LOG_LEVEL}  --select  ${selected_project}
    Log    ${dbt_run.stdout}
    Log    ${dbt_run.stderr}
    Log    ${dbt_run.rc}
    Should Be True    ${dbt_run.rc} < 3  msg= ${dbt_run.stderr}

DBT Run
    [Documentation]    Tests if the DBT run is successful
    [Arguments]    ${selected_project}
    ${dbt_run}=    Run Process     ${DBT_EXEC}  run  --log-level  ${DBT_LOG_LEVEL}  --select  ${selected_project}
    Log    ${dbt_run.stdout}
    Log    ${dbt_run.stderr}
    Log    ${dbt_run.rc}
    Should Be True    ${dbt_run.rc} < 3  msg= ${dbt_run.stderr}


