*** Settings ***
Library    Collections
Library    DateTime
Resource    Processing_Each_Purchase_Orders.robot
Library    RPA.Email.ImapSmtp

*** Variables ***
${primary_config}
${PRIMARY_PROCESS_NAME}    RPA0024-VTI
${SECONDARY_PROCESS_NAME}    RPA
${secondary_config}
${SID}


*** Keywords ***
Clear And Create Directory
    ${TEMP_FOLDER}=    Set Variable    ${primary_config['LocalFolder']}
    Remove Directory    ${TEMP_FOLDER}    force=True
    Create Directory        ${TEMP_FOLDER}

Prepare Working Environment
    [Documentation]    Initializes project folder structure and copies template files
    ${primary_fetched_config}=    Get All Settings    ${PRIMARY_PROCESS_NAME}
    ${secondary_fetched_config}=    Get All Settings    ${SECONDARY_PROCESS_NAME}
    Set Global Variable    ${primary_config}    ${primary_fetched_config}
    Set Global Variable    ${secondary_config}    ${secondary_fetched_config}
    Log To Console With Timestamp    Initializing project environment...
        
    Log To Console With Timestamp    Environment setup completed

Open Navision and VTI
    Evaluate                __import__('dotenv').load_dotenv(r'''${EXECDIR}/.env''')
    ${ENV}=    Get Environment Variable    ENV
    IF    '${ENV}' == 'UAT'
        ${SID}=    Set Variable    ${primary_config['DataName_Test']}
        Set Global Variable    ${SID}
    ELSE
        ${SID}=    Set Variable    ${primary_config['DataName']}
        Set Global Variable    ${SID}
    END
    Open Navision And VTI Test      ${FORCE_RESTART}    ${SID}


Processing Indent RPA and Purchase Orders
    ${merged_table_step_28}=    Open Indent RPA 
    ${log_file}=    Process Step29    ${merged_table_step_28}
    ${current_time}=    Get Time    format=%d/%m/%y %H:%M:%S
    ${email_body}=      Set Variable    Navision RPA Log List - ${current_time}
    # Send Email Final Report    ${log_file}    ${email_body}     RPA0024-VTI NavisionList
    ${destination_path} =     Set Variable    ${primary_config['LogPath']}
    Log To Console With Timestamp    ${destination_path}
    Copy File    ${log_file}    ${destination_path}

Open Navision And VTI Test
    [Arguments]      ${FORCE_RESTART}    ${SID}
    IF  ${FORCE_RESTART}
        Log To Console With Timestamp    FORCE_RESTART is ON – launching fresh NAV
        IF   "${SID}" == "VTI Livesystem"
            Launch NAV Via Citrix     ${True}
            ${microsoft_nav_STATUS}=    Run Keyword And Return Status    Wait for element    ${microsoft_nav}    timeout=140
            Log To Console With Timestamp     ${microsoft_nav_STATUS}
            Activate Nav Window Msnav Max   MSNAV    Role
            Wait For Element    image:${EXECDIR}${/}data${/}Images${/}VTI_P01_live.png     timeout=60
            RPA.Desktop.Click      image:${EXECDIR}${/}data${/}Images${/}VTI_P01_live.png
        ELSE
            Launch NAV Via Citrix       ${False}
            ${microsoft_nav_STATUS}=    Run Keyword And Return Status    Wait for element    ${microsoft_nav}    timeout=140
            Log To Console With Timestamp     ${microsoft_nav_STATUS}
            Activate Nav Window Msnav Max   MSNAV    Role
            Wait For Element     ${VTI_TEST_IMAGE}    timeout=80
            RPA.Desktop.Click      ${VTI_TEST_IMAGE}
        END
        Sleep   5s
        RPA.Desktop.Press Keys    enter
    ELSE
        Log To Console With Timestamp    NAV not running – launching via Citrix
        IF   "${SID}" == "VTI Livesystem"
            Launch NAV Via Citrix     ${True}
            ${microsoft_nav_STATUS}=    Run Keyword And Return Status    Wait for element    ${microsoft_nav}    timeout=140
            Log To Console With Timestamp     ${microsoft_nav_STATUS}
            Activate Nav Window Msnav Max   MSNAV    Role
            Wait For Element    image:${EXECDIR}${/}data${/}Images${/}VTI_P01_live.png     timeout=60
            RPA.Desktop.Click      image:${EXECDIR}${/}data${/}Images${/}VTI_P01_live.png
        ELSE
            Launch NAV Via Citrix       ${False}
            ${microsoft_nav_STATUS}=    Run Keyword And Return Status    Wait for element    ${microsoft_nav}    timeout=140
            Log To Console With Timestamp     ${microsoft_nav_STATUS}
            Activate Nav Window Msnav Max   MSNAV    Role
            Wait For Element     ${VTI_TEST_IMAGE}    timeout=80
            RPA.Desktop.Click      ${VTI_TEST_IMAGE}
        END
        Sleep   5s
        RPA.Desktop.Press Keys    enter
    END

Launch NAV Via Citrix
    [Arguments]     ${CHECK_SID}
    log to console      ${CHECK_SID}
    SeleniumLibrary.Open Browser    ${primary_config['URL_Citrix_Prod']}    edge
    Maximize Browser Window
    Evaluate                __import__('dotenv').load_dotenv(".env")
    ${PASSWORD}=    Get Environment Variable    NAVISION_PASS
    Wait Until Element Is Visible    id:protocolhandler-welcome-installButton    30s
    Click Element    id:protocolhandler-welcome-installButton
    Close Citrix Popup
    Wait Until Element Is Visible    id:legalstatement-checkbox2    30s
    Click Element    id:legalstatement-checkbox2
    Click Element    id:protocolhandler-detect-alreadyInstalledLink
    Wait Until Element Is Visible    id:username    30s
    Input Text       id:username    ${primary_config['Citrix_Username']}
    Input Password   id:password    ${PASSWORD}
    Click Element    id:loginBtn
    Wait Until Element Is Visible    xpath://li//p[contains(text(),'NAV Starter 2015 VT UiPath YOR')]/ancestor::li//a//img    30s
    IF    ${CHECK_SID}
        Click Element    xpath://li//p[contains(text(),'NAV Starter 2015 VT UiPath YOR')]/ancestor::li//a//img
    ELSE
        Click Element    xpath://li//p[contains(text(),'NAV Starter 2015 VT UiPath...est')]/ancestor::li//a//img
    END
    Open Latest Ica
    Close Browser



Extract And Save Clipboard Table
    [Arguments]    ${file_name}
    Sleep    3s
    Log To Console With Timestamp     HEre afte extracvt save
    ${clipboard}=    RPA.Desktop.Get Clipboard Value
    ${length}=    Get Length    ${clipboard}
    Run Keyword If    ${length} == 0    Fail    Clipboard is empty
    ${raw_table}    ${file_path}=
    ...    Save Clipboard Table
    ...    ${clipboard}
    ...    ${primary_config['LocalFolder']}
    ...    ${file_name}
    RETURN    ${raw_table}    ${file_path}

Open Indent RPA 
    Log To Console With Timestamp     Here before active nav widnow
    Activate Nav Window     Role Center     System
    Log To Console With Timestamp    Here
    Sleep    1s
    # Step  7 tp 10
    ${indent_table}    ${vendor_empty_table}    ${raw_indent_line_table}=
    ...    Prepare Indent Data
    ${final_indent_lines}    ${error_table}=
    ...    Process Indent Data
    ...    ${indent_table}
    ...    ${vendor_empty_table}
    ...    ${raw_indent_line_table}
    Log To Console With Timestamp      Here final indent line after steo 15 :- ${final_indent_lines}

    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Safe_check_before_Indent_Purchse.png     timeout=60
    RPA.Desktop.Click   image:${EXECDIR}${/}data${/}Images${/}Safe_check_before_Indent_Purchse.png
    Wait For Element     ${role_center}    timeout=80
    RPA.Desktop.Click      ${role_center}
    Log To Console With Timestamp    Role Center Clicked
    RPA.Desktop.Type Text    ${primary_config['IndentPath_Root']}
    RPA.Desktop.Press Keys      enter
    ${indent_purchase_verify}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Indent_Purchase.png   timeout=5

    ${error_table}=      Enrich Indent From Nav    ${final_indent_lines}    ${error_table}
    ${final_indent_lines}   ${error_table}=      Process ProfitCenter Validation    ${final_indent_lines}    ${error_table}
    Log To Console With Timestamp  Here after process profitcenter validation

    ${grouped_table}=    Group Indent Lines    ${final_indent_lines}
    ${po_table}=    Extract Purchase Orders
    ${merged_table}=    Merge Indent And PO Data    ${grouped_table}    ${po_table}
    ${merged_table}=    Handle Responsibilities And Map     ${merged_table}
    ${if_role_button}=   Run Keyword and Return Status  Wait for Element    ${role_center}      timeout=60
    IF   not ${if_role_button}
        RPA.Desktop.Click     ${back_button}
    END
    RETURN    ${merged_table}

Prepare Indent Data
    Log To Console With Timestamp    HEre waiting for ctrl f3 image
    Activate Nav Window     Role Center     system
    ${role_center_visible}=    Run Keyword And Return Status    Wait for element    ${Wait_for_role_center}    timeout=60
    Log To Console With Timestamp      ${role_center_visible}
    IF    not ${role_center_visible}
        Activate Nav Window     Role Center     system
        ${role_center_visible}=    Run Keyword And Return Status    Wait for element    ${Wait_for_role_center}    timeout=60
    END
    Log To Console With Timestamp     ${role_center_visible}
    # Fixed
    Wait For Element     ${role_center}    timeout=80
    RPA.Desktop.Click      ${role_center}
    Log To Console With Timestamp    Role Center Clicked
    RPA.Desktop.Type Text    ${primary_config['IndentPath']}
    RPA.Desktop.Press Keys      enter
    ${Indent_rpa_check_visible}=    Run Keyword And Return Status    Wait for element    ${Indent_rpa_check}    timeout=10
    Log To Console With Timestamp     Indent RPA Visible ${Indent_rpa_check_visible}
    ${description_header_visible}=     Run Keyword and Return Status    Wait For Element     ${Description_header_step_18}     timeout=60    interval=10
    Log To Console With Timestamp     found Desctipton header-- ${description_header_visible}
    wait for element    ${vendor_no}    timeout=10
    RPA.Desktop.Click    ${Description_header_step_18}     click
    Log To Console With Timestamp    Descrition Header clicked
    Press Custom Combination    ctrl    a
    Copy With Headers
    Log To Console With Timestamp    Here after copy header
    ${raw_table}    ${file_path}=    Extract And Save Clipboard Table    ${FILE_NAME_Indent_RPA}
    ${indent_table}=
    ...     Normalize Indent Table Indent Rpa
    ...     ${raw_table}
    ${row_count}=    Get Length    ${indent_table}
    Log To Console With Timestamp    Step 7 Rows Loaded: ${row_count}
    ${vendor_empty_table}=
    ...     Extract Vendor Empty
    ...     ${indent_table}
    ${empty_count}=    Get Length    ${vendor_empty_table}
    Log To Console With Timestamp    Step 8 Vendor Empty Rows: ${empty_count}
    ${indent_table}=
    ...     Remove Vendor Empty
    ...     ${indent_table}
    ${final_count}=    Get Length    ${indent_table}
    Log To Console With Timestamp    Step 9 Final Rows After Removal: ${final_count}
    ${if_role_button}=   Run Keyword and Return Status  Wait for Element    ${role_center}      timeout=20
    IF   not ${if_role_button}
        RPA.Desktop.Click     ${back_button}
    END
    Wait For Element     ${role_center}    timeout=80
    RPA.Desktop.Click      ${role_center}
    RPA.Desktop.Type Text    ${primary_config['IndentLinePath']}
    ${status_none}=    Run Keyword and Return Status     Wait For Element     ${Indent_line_rpa}     timeout=20
    RPA.Desktop.Press Keys    enter
    Log To Console With Timestamp  here in Open indent by SEarch Defore it descriptooinn
    ${found}=    Run Keyword And Return Status    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}row_item_check.png    timeout=25
    Run Keyword If    ${found}    
    ...    Log To Console With Timestamp    Table row appeared
    ...    ELSE    Log To Console With Timestamp    Table row did not appear yet

    Wait For Element     ${Description_header_step_18}    timeout=60
    RPA.Desktop.Click      ${Description_header_step_18}
    Press Custom Combination    ctrl    a
    # Sleep    10s
    Wait For Element     ${another_check}   timeout=10
    Log To Console With Timestamp      Found The Another check iamge
    Press Custom Combination    ctrl    shift   c
    ${raw_indent_line_table}    ${file_path_indent_line}=
    ...    Extract And Save Clipboard Table
    ...    ${FILE_NAME_Indent_Line}
    ${line_count}=    Get Length    ${raw_indent_line_table}
    Log To Console With Timestamp    Step 12 Rows: ${line_count}
    ${if_role_button}=   Run Keyword and Return Status  Wait for Element    ${role_center}      timeout=20
    IF   not ${if_role_button}
        RPA.Desktop.Click     ${back_button}
    END
    RETURN    ${indent_table}    ${vendor_empty_table}    ${raw_indent_line_table}

Process Indent Data
    [Arguments]    ${indent_table}    ${vendor_empty_table}    ${raw_indent_line_table}
    ${final_indent_lines}    ${error_table}=
    ...    Process Indent Lines
    ...    ${raw_indent_line_table}
    ...    ${indent_table}
    ...    ${vendor_empty_table}
    ${processed_count}=    Get Length    ${final_indent_lines}
    ${error_count}=        Get Length    ${error_table}
    Log To Console With Timestamp    Processed Lines: ${processed_count}
    Log To Console With Timestamp    Error Rows: ${error_count}
    RETURN    ${final_indent_lines}    ${error_table}

Enrich Indent From NAV
    [Arguments]    ${final_indent_lines}    ${error_table}
    ${table_length}=    Get Length    ${final_indent_lines}
    Log To Console With Timestamp    Table Length: ${table_length}
    Run Keyword If    ${table_length} > 0
    ...    Log To Console With Timestamp
    ...    Keys In First Row: ${final_indent_lines[0].keys()}
    Log To Console With Timestamp    HEre in Enrich Before For loop
    FOR    ${row}    IN    @{final_indent_lines}
        ${doc_no}=    Evaluate    ($row.get("Document No.") or $row.get("Document No") or "").strip()
        Log To Console With Timestamp    Step 18 Processing: ${doc_no}
        RPA.Desktop.Press Keys    f3
        Sleep    2s
        Press Custom Combination    ctrl    a
        Sleep    0.5s
        RPA.Desktop.Press Keys    backspace
        Sleep    0.5s
        RPA.Desktop.Type Text    ${doc_no}
        RPA.Desktop.Press Keys    enter
        Wait For Element    ${Description_header_step_18}    timeout=60
        RPA.Desktop.Click    ${Description_header_step_18}
        Sleep    1s
        RPA.Desktop.Clear Clipboard
        Press Custom Combination    ctrl    a
        Sleep    1s
        Press Custom Combination    ctrl    shift    c
        Sleep    1s
        ${clipboard}=    RPA.Desktop.Get Clipboard Value
        Log To Console With Timestamp      Row extracted from table :- ${clipboard}
        ${status}    ${result}=
        ...    Run Keyword And Ignore Error
        ...    Extract And Save Clipboard Table
        ...    temp_nav_extract.csv
        IF    '${status}' == 'FAIL'
            Log To Console With Timestamp    Clipboard failed for ${doc_no}
            CONTINUE
        END
        ${nav_table}    ${path}=    Set Variable    ${result}
        ${status2}    ${extract_result}=
        ...    Run Keyword And Ignore Error
        ...    Extract Nav Details
        ...    ${nav_table}
        IF    '${status2}' == 'FAIL'
            Log To Console With Timestamp    Extraction failed for ${doc_no}
            CONTINUE
        END
        ${indent_no}    ${priority}    ${profit_center}=    Set Variable    ${extract_result}
        Set To Dictionary    ${row}    Indent No        ${indent_no}
        Set To Dictionary    ${row}    Priority         ${priority}
        Set To Dictionary    ${row}    ProfitCenter     ${profit_center}
        IF    '${profit_center}' == '' or '${profit_center}' == 'null'
            ${error_row}=    Create Dictionary
            ...    Document No.    ${row["Document No."]}
            ...    No.             ${row["No."]}
            ...    Description     ${row["Description"]}
            ...    Vendor No.      ${row["Vendor No."]}
            ...    Due Date        ${row["Due Date"]}
            ...    Error           Missing ProfitCenter code in Indent Header
            Append To List    ${error_table}    ${error_row}
        END
    END
    RETURN    ${error_table}

Process ProfitCenter Validation
    [Arguments]    ${final_indent_lines}    ${error_table}
    log to console      Here in Error Table:- ${error_table}
    ${before_count}=    Get Length    ${final_indent_lines}
    Log To Console With Timestamp    Before Step 19 Count: ${before_count}
    ${final_indent_lines}=
    ...    Evaluate
    ...    [row for row in ${final_indent_lines} if row.get("ProfitCenter")]
    ${after_count}=    Get Length    ${final_indent_lines}
    Log To Console With Timestamp    After Step 19 Count: ${after_count}
    ${error_path}=    Set Variable    ${primary_config['LocalFolder']}${/}IndentLine_ERRORlist.csv
    
    ${is_empty}=    Evaluate    len(${error_table}) == 0

    IF    ${is_empty}
        Log To Console With Timestamp    No errors found → creating empty CSV with headers

        ${empty_row}=    Create Dictionary
        ...    Document No.=
        ...    No.=
        ...    Description=
        ...    Vendor No.=
        ...    Due Date=
        ...    Error=

        ${error_table}=    Create List    ${empty_row}
    END

    # Write CSV (using RPA.Tables)
    ${table}=    Create Table    ${error_table}
    RPA.Tables.Write Table To CSV    ${table}    ${error_path}
    ${body}=    Set Variable    <html><body><p>Hello Buyer</p><p>Please, check the attached list ...</p><p>Voith RPA</p></body></html>
    # Send Email Final Report    ${error_path}    ${body}    RPA0024-VTI Error In Navision Indent LIne
    Log To Console With Timestamp    Error CSV written to: ${error_path}
    RETURN      ${final_indent_lines}    ${table}

Extract Purchase Orders
    Log To Console With Timestamp    Opening Purchase Orders RPA
    ${if_role_button}=   Run Keyword and Return Status  Wait for Element    ${role_center}      timeout=20
    IF   not ${if_role_button}
        RPA.Desktop.Click     ${back_button}
    END
    Wait For Element     ${role_center}    timeout=80
    RPA.Desktop.Click      ${role_center}
    Log To Console With Timestamp    Role Center Clicked
    RPA.Desktop.Type Text    ${primary_config['PurchaseOrderPath']}
    RPA.Desktop.Press Keys      enter
    ${purchase_order_verify}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Purchase_Order_verify.png      timeout=10
    RPA.Desktop.Press Keys    enter
    Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Reference_button_PO_Step_23.png     timeout=60
    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Reference_button_PO_Step_23.png
    Press Custom Combination    ctrl    a
    Sleep    1s
    Press Custom Combination    ctrl    shift    c
    ${copying_appeared}=    Run Keyword And Return Status
    ...    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Copying_process_check.png    timeout=10
    Log To Console With Timestamp      ${copying_appeared}
    IF    ${copying_appeared}
        FOR    ${i}    IN RANGE    30
            ${still_copying}=    Run Keyword And Return Status
            ...    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Copying_process_check.png    timeout=2
            IF    not ${still_copying}
                BREAK
            END
        END
    END
    ${po_csv_path}=    Set Variable    ${primary_config['LocalFolder']}${/}POList.csv
    ${status}    ${po_result}=
    ...    Run Keyword And Ignore Error
    ...    Extract And Save Clipboard Table
    ...    ${po_csv_path}
    ${po_table}    ${path}=    Set Variable    ${po_result}
    ${po_count}=    Get Length    ${po_table}
    Log To Console With Timestamp    PO rows loaded Before checking: ${po_count}
    IF    '${status}' == 'FAIL'
        Log To Console With Timestamp    PO extraction failed
        ${po_table}=    Create List
    ELSE
        ${po_table}    ${path}=    Set Variable    ${po_result}
    END
    ${po_count}=    Get Length    ${po_table}
    Log To Console With Timestamp    PO rows loaded: ${po_count}
    ${if_role_button}=   Run Keyword and Return Status  Wait for Element    ${role_center}      timeout=20
    IF   not ${if_role_button}
        RPA.Desktop.Click     ${back_button}
    END
    RETURN    ${po_table}

Merge Indent And PO Data
    [Arguments]    ${grouped_table}    ${po_table}
    ${merged_table}=    Create List
    FOR    ${row}    IN    @{grouped_table}
        ${doc_type}=     Get From Dictionary    ${row}    DocumentType    default=${EMPTY}
        ${doc_no}=       Get From Dictionary    ${row}    Document No.    default=${EMPTY}
        ${indent_ref}=   Get From Dictionary    ${row}    Indent Reference/Status    default=${EMPTY}
        ${priority}=     Get From Dictionary    ${row}    Priority    default=${EMPTY}
        ${pc}=           Get From Dictionary    ${row}    ProfitCenter    default=${EMPTY}
        ${vendor}=       Get From Dictionary    ${row}    Vendor No.    default=${EMPTY}
        ${due}=          Get From Dictionary    ${row}    Due Date    default=${EMPTY}
        ${status}=       Get From Dictionary    ${row}    Status    default=${EMPTY}
        ${new_row}=    Create Dictionary
        ...    DocumentType=${doc_type}
        ...    DocumentNo=${doc_no}
        ...    Indent Reference/Status=${indent_ref}
        ...    Priority=${priority}
        ...    ProfitCenter=${pc}
        ...    Vendor No=${vendor}
        ...    Due Date=${due}
        ...    Status=${status}
        ...    Purchaser Name=${EMPTY}
        ...    Assigned User ID=${EMPTY}
        Append To List    ${merged_table}    ${new_row}
    END
    FOR    ${row}    IN    @{po_table}
        ${doc_no}=     Get From Dictionary    ${row}    No.    default=${EMPTY}
        ${vendor}=     Get From Dictionary    ${row}    Buy-from Vendor No.    default=${EMPTY}
        ${status}=     Get From Dictionary    ${row}    Status    default=${EMPTY}
        ${assigned}=   Get From Dictionary    ${row}    Assigned User ID    default=${EMPTY}
        ${new_row}=    Create Dictionary
        ...    DocumentType=Order
        ...    DocumentNo=${doc_no}
        ...    Indent Reference/Status=Released
        ...    Priority=${EMPTY}
        ...    ProfitCenter=${EMPTY}
        ...    Vendor No=${vendor}
        ...    Due Date=${EMPTY}
        ...    Status=${status}
        ...    Purchaser Name=${EMPTY}
        ...    Assigned User ID=${assigned}
        Append To List    ${merged_table}    ${new_row}
    END
    ${merged_count}=    Get Length    ${merged_table}
    Log To Console With Timestamp    Merged rows count: ${merged_count}
    ${merged_output}=    Set Variable    ${primary_config['LocalFolder']}${/}Merged_Table_Step26.csv
    python_helper.Write Table To Csv    ${merged_table}    ${merged_output}
    RETURN    ${merged_table}

Handle Responsibilities And Map
    [Arguments]    ${merged_table}
    ${download_path}=    Set Variable    %{USERPROFILE}${/}Downloads
    ${temp_path}=        Set Variable    ${primary_config['LocalFolder']}
    ${responsibility_file_path}=    Set Variable      ${primary_config['Responsibilities']}
    Copy File
    ...    ${responsibility_file_path}
    ...    ${temp_path}\\Responsibilities.xlsx
    Log To Console With Timestamp    ===== START RESPONSIBILITY FILE READ =====
    ${resp_file}=    Set Variable    ${temp_path}\\Responsibilities.xlsx
    File Should Exist    ${resp_file}
    Open Workbook    ${resp_file}
    ${resp_table}=    Read Worksheet As Table    name=All Vendor    header=True
    Close Workbook
    Log To Console With Timestamp    ===== END RESPONSIBILITY FILE READ =====
    ${updated_table}=    Map Responsibilities To Merged Table
    ...    ${merged_table}
    ...    ${resp_table}
    RETURN    ${updated_table}


Map Responsibilities To Merged Table
    [Arguments]    ${merged_table}    ${resp_table}
    ${supplier_map}=    Create Dictionary
    FOR    ${resp}    IN    @{resp_table}
        ${supplier_no}=    Get From Dictionary    ${resp}    Supplier No.    default=${EMPTY}
        IF    $supplier_no
            ${supplier_no}=    Convert To String    ${supplier_no}
            ${supplier_no}=    Strip String    ${supplier_no}
            Set To Dictionary    ${supplier_map}    ${supplier_no}    ${resp}
        END
    END
    FOR    ${row}    IN    @{merged_table}
        ${vendor}=    Get From Dictionary    ${row}    Vendor No    default=${EMPTY}
        IF    $vendor
            ${vendor}=    Convert To String    ${vendor}
            ${vendor}=    Strip String    ${vendor}
            IF    $vendor.startswith("VT")
                Continue For Loop
            END
            ${match}=    Get From Dictionary    ${supplier_map}    ${vendor}    default=${None}
            IF    $match is not None
                ${purchase_name}=    Get From Dictionary    ${match}    Purchaser Responsible    default=${EMPTY}
                ${assigned_id}=      Get From Dictionary    ${match}    Assigned User ID    default=${EMPTY}
                Set To Dictionary    ${row}    Purchaser Name    ${purchase_name}
                Set To Dictionary    ${row}    Assigned User ID    ${assigned_id}
            ELSE
                Set To Dictionary    ${row}    Status    Supplier not found in Responsibilities
            END
        END
    END
    RETURN    ${merged_table}

Send Email Final Report    
    [Arguments]    ${log_path}    ${body}    ${subject}

    ${final_body}=    Set Variable If    '${body}' == ''    ${primary_config['eBody']}    ${body}
    ${email_sender}=       Set Variable    ${primary_config['Email_Sender']}
    ${email_recipient}=    Set Variable    ${primary_config['E-mail_Team']}
    ${email_subject}=      Set Variable IF   '${subject}' == ''    Testing - RPA0024- Navision Purchase VTI     ${subject}
    log to console      This is the Subject we Have :- ${email_subject} and Log path :- ${log_path}
    Authorize SMTP
    ...    account=${email_sender}
    ...    password=${EMPTY}
    ...    smtp_server=${secondary_config['SMTP_Server']}
    ...    smtp_port=${secondary_config['SMTP_Port']}
    Log To Console With Timestamp    Preparing to send final report to ${email_recipient} And ${log_path}...
    Send Message
    ...    sender=${email_sender}
    ...    recipients=${email_recipient}
    ...    subject=${email_subject}
    ...    body=${final_body}
    ...    html=True
    ...    attachments=${log_path}
    Log To Console With Timestamp    📧 Report successfully sent with attached log!


Log To Console With Timestamp
    [Documentation]    Logs message to console with timestamp prefix
    [Arguments]    ${message}
    ${timestamp}=    DateTime.Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Log To Console    [${timestamp}] ${message}
