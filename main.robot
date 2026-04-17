*** Settings ***
# Library    RPA.Browser.Selenium
Library     Process
Library     adapters/Library/RobotProcessLibrary.py
Resource    flow/navision_full_flow.robot

*** Test Cases ***
RPA0024-VTI
    [Documentation]    Main test to process and archive purchase order emails
    # Initialize Robot Process
    End To End NAV Smart Flow
    # End Robot Process