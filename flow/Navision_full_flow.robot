*** Settings ***
Resource    ../domain/Processing_Indent_Data.robot
Resource    ../domain/Processing_Each_Purchase_Orders.robot
Library    ../adapters/Python_helper.py
Library    ../adapters/db_adapters.py
Resource    ../Resources/locators.robot
Library     ../adapters/Library/InitAllSettingsSQL.py
Library    RPA.Windows
Library    RPA.Desktop
Library    OperatingSystem
Library    Collections
Library    Process
Library    SeleniumLibrary
Library    RPA.Excel.Files
Library    RPA.Tables
Library    String

 

*** Keywords ***
End To End NAV Smart Flow
    # Closing Existing Navision Windows
    Close Existing Navision

    # Environment and Config Setup
    Prepare Working Environment

    # # Remove Existing Directories and Creating new
    Clear And Create Directory

    # Opening Navision VTI for Processing
    Open Navision and VTI
    # Processing Each PO and Indents...
    Processing Indent RPA and Purchase Orders
    # Close Nav Window
    Close Existing Navision

