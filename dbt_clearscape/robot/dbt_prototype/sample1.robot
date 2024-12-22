*** Settings ***
Documentation     This .robot file is a suite
...
...               Keywords are imported from the resource file
Library           DateTime

*** Keywords ***
Store Text
    [Arguments]    ${text}
    log    The text "${text}" will be store in the variable \${stored_text}.
    Set Suite Variable    ${stored_text}    ${text}

Add Text To Stored Text
    [Arguments]    ${text}
    ${full_text}=    Set Variable    ${stored_text} ${text}
    Log    The resulting text is: ${full_text}
    Set Suite Variable    ${stored_text}    ${full_text}

Verify Stored Text Length
    [Arguments]    ${expected_length}
    Length Should Be    ${stored_text}    ${expected_length}

Get Stored Text
    [Return]    ${stored_text}

Check Correct Greeting
    [Arguments]    ${greeting}
    IF   $greeting == 'Hail Our Robot Overlords!'
        Log To Console    \nYou may proceed...
    ELSE
        Fail    Sorry. But that was the wrong answer... Bye Bye...
    END

*** Test Cases ***
Simple Test Case
    [Documentation]    Shows some assertion keywords
    Should Be Title Case    Robot Framework
    Should Be Equal    Text123    Text123
    Should Be True    5 + 5 == 10

Test with Keywords
    Store Text    Hail Our Robot
    Add Text To Stored Text     Overlords!
    Verify Stored Text Length    25
    ${current_text}=    Get Stored Text
    Should Be Equal    ${current_text}    Hail Our Robot Overlords!

Test for the year 2022
    [Documentation]    Tests if it is still 2022...
    ${date}=    Get Current Date    result_format=datetime
    Log    ${date}
    Should Be Equal As Strings    ${date.year}    2022

Test Case that fails
    Check Correct Greeting    Hail Our Robot Overlords!
    Check Correct Greeting    Hello World!
