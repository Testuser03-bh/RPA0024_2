*** Settings ***
Library    Collections
Library    DateTime
Library    OperatingSystem
Library    ../adapters/Python_helper.py

*** Variables ***
${primary_config}
${PRIMARY_PROCESS_NAME}    RPA0024-VTI
${SECONDARY_PROCESS_NAME}    RPA
${secondary_config}

*** Keywords ***
Process Step 29
    [Arguments]    ${table}
    ${primary_fetched_config}=    Get All Settings    ${PRIMARY_PROCESS_NAME}
    ${secondary_fetched_config}=    Get All Settings    ${SECONDARY_PROCESS_NAME}
    Set Global Variable    ${primary_config}    ${primary_fetched_config}
    Set Global Variable    ${secondary_config}    ${secondary_fetched_config}
    Log To Console With Timestamp    ===== STARTING STEP 29 PROCESS =====
    ${otuput_csv}=      Set Variable    ${primary_config['LocalFolder']}${/}RPA0024_Navision_VTI.csv
    ${output_csv_29_phase}=   Set Variable    ${primary_config['LocalFolder']}VTI_LogData.csv
    ${table}=    Process Step 29 Backend       ${table}  
    ${table}=    RPA.Tables.Create Table    ${table}
    ${leading_pc}=   Set Variable   ${EMPTY}
    ${max_iteration}=   Set Variable      5
    FOR    ${index}    ${row}    IN ENUMERATE    @{table}
        ${status}=    Set Variable    ${row["Status"]}
        ${po}=    Set Variable    ${row["DocumentNo"]}
        Log To Console With Timestamp      Here :- ${po}

        # Technically Checked — every iteration regardless of outcome
        NAV Increment Technically Checked

        # Skip invalid rows — missing DocumentNo
        IF    '${po}' == '' or '${po}' == None
            Log To Console With Timestamp    Skipping invalid row — missing DocumentNo at index ${index}
            CONTINUE
        END

        ${indent_status}=    Set Variable    ${row["Indent Reference/Status"]}
        ${current_PO_Step}=    Get PO Step  ${po}
        # Fixed
        IF   '${current_PO_Step}' == ''
            ${current_PO_Step}=    Set Variable    0
        END
        Log To Console With Timestamp      Status of ${po} - ${status}, Here Index Value - ${index}
        IF    '${status}' == '' and ${index}<100
        # IF    '${status}' == '' 
            Log To Console With Timestamp    Index Value ${index}
            # Step 29.2 onward
            IF    '${current_PO_Step}' == None
                Set To Dictionary    ${row}    status=Po Step is None
                Break
            END
            IF      ${current_PO_Step} == 0
                Log To Console With Timestamp   Calling Step 29_2 Phase 2
                ${row}    ${leading_pc}=    Process Step 29_2    ${row}    ${table}    ${index}    ${current_PO_Step}
            # 29.3
            ELSE IF      ${current_PO_Step} == 1
                Log To Console With Timestamp   29.3 – PO Step = 1
                ${result}=    Update PO Step    ${po}   3
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 3 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
                ${is_open}=    Evaluate    $indent_status.lower() == 'open'
                IF    ${is_open}
                    Set To Dictionary    ${row}    Status=PO approval rejected
                ELSE
                    ${row}    ${leading_pc}=    Process Step 29_2    ${row}    ${table}    ${index}    ${current_PO_Step}
                END

            #  29.4
            ELSE IF      ${current_PO_Step} == 2
                Log To Console With Timestamp    message=29.4 – PO Step = 2
                ${is_open}=    Evaluate    $indent_status.lower() == 'open'
                IF    ${is_open}
                    Set To Dictionary    ${row}    Status=PO reopened
                ELSE
                    Set To Dictionary    ${row}    Status=PO approved and waiting to be posted
                END
            
            # 29.5
            ELSE IF      ${current_PO_Step} == 3
                Log To Console With Timestamp   29.5 – PO Step = 3
                ${is_open}=    Evaluate    $indent_status.lower() == 'open'
                IF    ${is_open}
                    Set To Dictionary    ${row}    Status=PO rejected and still waiting for approval or reopened
                ELSE
                    ${result}=    Update PO Step    ${po}   1
                    IF    ${result}
                        Log To Console With Timestamp    Purchase order ${po} updated to Step 1 successfully.
                    ELSE
                        Log To Console With Timestamp    Failed to update purchase order ${po}.
                    END                    
                    ${row}    ${leading_pc}=    Process Step 29_2    ${row}    ${table}    ${index}    ${current_PO_Step}
                END
            # 29.6
            ELSE IF      ${current_PO_Step} == 9
                Log To Console With Timestamp   29.6 – PO Step = 9
                Activate Nav Window    Purchase Order RPA
                Open Order Page And PO      ${po}
                ${row}    ${error_message}=    Send_PO_PDF    ${row}
                # 29.6.6 Udpate to po_step 9
                ${result}=    Update PO Step    ${po}   9
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END

                IF   $error_message == ''
                    ${result}=    Update PO Step    ${po}   2
                    IF    ${result}
                        Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                    ELSE
                        Log To Console With Timestamp    Failed to update purchase order ${po}.
                    END
                END
                ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
                IF   ${ok_button_status}
                    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
                END
            END
            IF    '${leading_pc}' == ''
                Log To Console With Timestamp    leading_pc not retrieved - fetching now
                ${leading_pc}=    Open_And_Extract_PO_Data    ${po}    ${False}
                ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
                IF   ${ok_button_status}
                    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
                    ${ok_clicked}=    Set Variable    True  
                END
            ELSE
                Log To Console With Timestamp    leading_pc already retrieved: ${leading_pc} - skipping NAV
            END
            IF    '${leading_pc}' != ''
                Set To Dictionary     ${row}    ProfitCenter=${leading_pc}
            END
        NAV Increment Done And Technically Checked
        RPA.Tables.Set Table Row    ${table}    ${index}    ${row}
        RPA.Tables.Write Table To CSV      ${table}      ${output_csv_29_phase}
        END
    END
    RPA.Tables.Write Table To CSV      ${table}      ${output_csv_29_phase}
    Log To Console With Timestamp    ===== STEP 29 COMPLETED =====
    RETURN    ${output_csv_29_phase}

Process Step 29_2
    [Arguments]    ${row}    ${table}    ${index}    ${po_step}
    ${ok_clicked}=    Set Variable    ${False}
    Log to console with timestamp     Here in Step 29_2
    ${po}=    Set Variable    ${row["DocumentNo"]}
    Log To Console With Timestamp    Processing PO: ${po}
    ${leading_pc}    ${is_mrp}    ${is_rework}    ${vendor}=
    ...    Open_And_Extract_PO_Data    ${po}
    ${indent_status}=    Set Variable    ${row["Indent Reference/Status"]}
    Log To Console With Timestamp      ${indent_status}
    ${unit_check}=    Set Variable    False
    @{UnitPurchaseCompany}=    Split String    ${primary_config['UnitPurchaseCompany']}    |
    IF    "${vendor}".startswith("VT")
        FOR    ${Unit}    IN    @{UnitPurchaseCompany}
            ${match}=    Run Keyword And Return Status
            ...    Should Contain    ${vendor}    ${Unit}
            IF    ${match}
                ${unit_check}=    Set Variable    True
                Exit For Loop
            END
        END
    END
    ${check_po_again}=    Get PO Step    ${po}
    IF   '${po_step}' != '${check_po_again}'
        ${is_rework}=   Set Variable    True
    END
    IF    ${is_mrp} and not ${is_rework} and $indent_status == 'Open'
        Log To Console With Timestamp      Here 29.2.8
        Wait For Element     image:${EXECDIR}${/}data${/}Images${/}General_section.png     timeout=60
        RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}General_Section.png
        Press Custom Combination    alt    f6
        ${found}=   Run Keyword And Return Status
        ...     Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Line_section_open_or_not.png     timeout=40
        IF  ${found}
            Log To Console With Timestamp      Here 29.2.8.2
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Line_section.png
            Press Custom Combination    alt    f6
        END
        Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Shipping_section.png     timeout=60
        RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Shipping_Section.png
        Sleep   1s
        Press Custom Combination    alt    f6
        Sleep   2s
        Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Requested_reciept_date_29.2.8.4.png     timeout=60
        RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Requested_reciept_date_29.2.8.4.png
        RPA.Desktop.Clear Clipboard
        RPA.Desktop.Press Keys      left
        Sleep   1s
        Press Custom Combination      ctrl    a
        Sleep   1s
        Press Custom Combination      ctrl    c
        Sleep   1s
        ${requested_date}=    RPA.Desktop.Get Clipboard Value
        Log To Console With Timestamp      Here with REquested date ${requested_date}
        IF    '${requested_date}' == ''
            Set To Dictionary
            ...    ${row}
            ...    Status=Requested Receipt Date not found in MRP Order
        ELSE
            ${expected_date}=    Calculate Expected Receipt Date
            ...    ${requested_date}
            ...    ${row["Priority"]}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Expected_date_step_29_2_8_5.png
            RPA.Desktop.Press Keys      left
            Press Custom Combination       ctrl    a
            RPA.Desktop.Press Keys      backspace
            Log To Console With Timestamp      ${expected_date}
            RPA.Desktop.Type Text       ${expected_date}
            RPA.Desktop.Press Keys      enter
            RPA.Desktop.Press Keys      left
            RPA.Desktop.Press Keys      enter
            Wait For Element     image:${EXECDIR}${/}data${/}Images${/}General_section.png     timeout=60
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}General_Section.png
            Press Custom Combination    alt    f6
            Sleep   2s
            Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Your_reference_29_2_4.png     timeout=60
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Your_reference_29_2_4.png
            RPA.Desktop.Press Keys    backspace
            RPA.Desktop.Type Text     MRP
            RPA.Desktop.Press Keys  alt
            Sleep   0.5s
            RPA.Desktop.Press Keys  f
            Sleep   0.5s
            RPA.Desktop.Press Keys  alt
            Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Position_numbering_29_2_8_9.png     timeout=60
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Position_numbering_29_2_8_9.png
            Wait For Element     image:${EXECDIR}${/}data${/}Images${/}By_step_20_2_8_10.png     timeout=60
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}By_step_20_2_8_10.png
            RPA.Desktop.Press Keys    backspace
            RPA.Desktop.Type Text     100
            Press Custom Combination    ctrl    enter
            Sleep    2s
            RPA.Desktop.Press Keys  alt
            Sleep   0.5s
            RPA.Desktop.Press Keys  a
            Sleep   0.5s
            RPA.Desktop.Press Keys  a
            Sleep   0.5s
            RPA.Desktop.Press Keys  p
            ${error_popup}=    Run Keyword And Return Status    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png    timeout=20
            RPA.Desktop.Click       image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png
            IF    ${error_popup}
                Sleep      0.5s
                Press Custom Combination    ctrl    a
                Sleep      1s
                Press Custom Combination    ctrl    c
                Sleep      3s
                ${error_message}=    RPA.Desktop.Get Clipboard Value
                ${error_message}=    Strip String     ${error_message}

                Log to console      HEre is the Error Message ${error_message}
                ${error_message}=    Replace String    ${error_message}    \r\n    ''
                RPA.Desktop.Press Keys      enter   
                Log to console with timestamp        Here in Step 29.2 ${error_message}
                Set To Dictionary    ${row}    Status=Please check the PO. The buyer needs to finalize the process and change the Purchaser Code
                ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
                IF   ${ok_button_status}
                    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
                    ${ok_clicked}=    Set Variable    True  
                END
                        
            END
            # porperly Aligned wiht Doc
            IF  $indent_status != "Open" and not ${ok_clicked}
                Set To Dictionary
                ...    ${row}
                ...    Status=MRP Purchase Order sent to approval

                ${result}=    Insert PO Step    ${po}   1
                IF    ${result}
                    Log To Console With Timestamp    Purchase order inserted successfully.
                ELSE
                    Log To Console With Timestamp    Failed to insert purchase order.
                END
                
                ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
                IF   ${ok_button_status}
                    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
                    ${ok_clicked}=    Set Variable    True  
                END
            END
        END
    # 29.2.9
    ELSE IF    ${po_step} == 0 and not ${is_mrp} and $indent_status != 'Open'
        Set To Dictionary    ${row}    Status=Please check the PO. The buyer needs to finalize the process and change the Purchaser Code
        Set List Value    ${table}    ${index}    ${row}
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    # 29.2.10
    ELSE IF    ${po_step} == 2 and not ${is_mrp}
        Log To Console With Timestamp   29.2.10 – Not MRP + Step = 2
        Set To Dictionary
        ...    ${row}
        ...    Status=No action for this Purchase Order
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    # 29.2.11
    ELSE IF    ${is_mrp} and ${is_rework} and ${po_step} == 2
        Log To Console With Timestamp      In step 29.2.11
        Set To Dictionary
        ...    ${row}
        ...    Status=No action for this Purchase Order
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    # 29.2.12
    ELSE IF    not ${is_mrp} and ${po_step} == 0 and $indent_status == 'Open'
        Log To Console With Timestamp      Step 29.2.12
        Set To Dictionary
        ...    ${row}
        ...    Status=PO open, please check and request approval
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    # 29.2.13
    ELSE IF    ${is_mrp} and ${is_rework} and ${po_step} == 0 and $indent_status == 'open'
        Log To Console With Timestamp      29.2.13
        Set To Dictionary
        ...    ${row}
        ...    Status=PO open, please check and request approval
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    # 29.2.14
    ELSE IF    not ${is_mrp} and ${po_step} != 2 and ${po_step} != 0 and $indent_status != 'Open'
        Log To Console With Timestamp   29.2.14 – Insert DB
        ${result}=    Insert PO Step    ${po}   1
        IF    ${result}
            Log To Console With Timestamp    Purchase order inserted successfully.
        ELSE
            Log To Console With Timestamp    Failed to insert purchase order.
        END
        Log To Console With Timestamp      Here in Else if of 2.14
        IF    $vendor.startswith('VT')
            ${row}      ${error_message}=    Send_PO_BizTalk      ${row}
            IF      $error_message == ''
                ${result}=    Update PO Step    ${po}   2
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            ELSE
                ${result}=    Update PO Step    ${po}   9
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            END
            Log To Console With Timestamp      After VT talkcomplete
        ELSE
            ${row}      ${error_message}=    Send_PO_PDF    ${row}
            ${ok_clicked}=      Set Variable    True
            IF      $error_message == ''
                ${result}=    Update PO Step    ${po}   2
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            ELSE 
                ${result}=    Update PO Step    ${po}   9
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            END
        END
        
    # 29.2.15
    ELSE IF    ${is_mrp} and ${is_rework} and ${po_step} != 2 and ${po_step} == 0 and $indent_status != 'Open'
        Log To Console With Timestamp   29.2.15 – MRP + Rework + Step != 2 + Step == 0 + Indent not OPEN
        ${result}=    Insert PO Step    ${po}   1
        IF    ${result}
            Log To Console With Timestamp    Purchase order inserted successfully.
        ELSE
            Log To Console With Timestamp    Failed to insert purchase order.
        END        
        IF    $vendor.startswith('VT')
            ${row}      ${error_message}=    Send_PO_BizTalk      ${row}
            IF      $error_message == ''
                ${result}=    Update PO Step    ${po}   2
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            ELSE
                ${result}=    Update PO Step    ${po}   9
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            END
            Log To Console With Timestamp      After VT talkcomplete
        ELSE
            ${row}      ${error_message}=    Send_PO_PDF    ${row}
            ${ok_clicked}=      Set Variable    True
            IF      $error_message == ''
                ${result}=    Update PO Step    ${po}   2
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            ELSE 
                ${result}=    Update PO Step    ${po}   9
                IF    ${result}
                    Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
                ELSE
                    Log To Console With Timestamp    Failed to update purchase order ${po}.
                END
            END
        END
    # 29.2.16
    ELSE IF    not ${is_mrp} and ${po_step} != 2 and ${po_step} != 0 and $vendor.startswith('VT')
        Log To Console With Timestamp   29.2.16 – Not MRP + Step != 2 + Step != 0 + Vendor starts VT
        ${row}      ${error_message}=    Send_PO_BizTalk      ${row}
        IF      $error_message == ''
            ${result}=    Update PO Step    ${po}   2
            IF    ${result}
                Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
            ELSE
                Log To Console With Timestamp    Failed to update purchase order ${po}.
            END
        ELSE 
            ${result}=    Update PO Step    ${po}   9
            IF    ${result}
                Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
            ELSE
                Log To Console With Timestamp    Failed to update purchase order ${po}.
            END
        END
    
    # 29.2.17
    ELSE IF    ${is_mrp} and ${is_rework} and ${po_step} != 2 and ${po_step} != 0 and not $vendor.startswith('VT')
        Log To Console With Timestamp      29.2.17 – MRP + Rework + Step != 2 + Step != 0 + Vendor NOT VT
        ${row}      ${error_message}=    Send_PO_PDF    ${row}
            ${ok_clicked}=      Set Variable    True
        IF      $error_message == ''
            ${result}=    Update PO Step    ${po}   2
            IF    ${result}
                Log To Console With Timestamp    Purchase order ${po} updated to Step 2 successfully.
            ELSE
                Log To Console With Timestamp    Failed to update purchase order ${po}.
            END
        ELSE
            ${result}=    Update PO Step    ${po}   9
            IF    ${result}
                Log To Console With Timestamp    Purchase order ${po} updated to Step 9 successfully.
            ELSE
                Log To Console With Timestamp    Failed to update purchase order ${po}.
            END
        END
    END
    Log To Console With Timestamp      HEre before step 18
    IF   not ${ok_clicked}
        ${ok_button_status}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png    timeout=60
        IF   ${ok_button_status}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Ok_button_29_2_8_14.png
            ${ok_clicked}=    Set Variable    True  
        END
    END
    ${window_title}=    RPA.Windows.List Windows
    ${is_po_window}=    Evaluate    '${po}' in $window_title
    IF    ${is_po_window}
        Log To Console With Timestamp    Force closing Edit PO window for ${po}
        Press Custom Combination    alt    f4
    END
    Log To Console With Timestamp    Window closed for PO: ${po}
    Log To Console With Timestamp      ${row}
    Log To Console With Timestamp      ------------------------------
    RETURN    ${row}     ${leading_pc}

Send_PO_BizTalk
    [Arguments]     ${row}
    Log To Console With Timestamp      Here in BIZTALK
    RPA.Desktop.Press Keys      alt
    Sleep   0.5s
    RPA.Desktop.Press Keys      a
    Sleep   0.5s
    RPA.Desktop.Press Keys      e
    Sleep   0.5s
    RPA.Desktop.Press Keys      s
    Sleep   0.5s
    RPA.Desktop.Clear Clipboard
    ${error_message}=       Set Variable    None
    ${erro_popup}=    Run Keyword And Return Status
    ...    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png    timeout=3
    IF    ${erro_popup}
        RPA.Desktop.Clear Clipboard
        Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png    timeout=60
        RPA.Desktop.Click       image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png
        Sleep   5s
        Press Custom Combination    ctrl    c
        Sleep    2s
        ${error_message}=    RPA.Desktop.Get Clipboard Value
        ${error_message}=    Replace String    ${error_message}    \r\n    ''  
        RPA.Desktop.Press Keys      enter
        IF    'already sent' in $error_message.lower().lower()
            Set To Dictionary
            ...    ${row}
            ...    Status=Sending not Possible, Order Already sent!
        ELSE
            Log To Console With Timestamp  Error message :- ${error_message}
            Set To Dictionary
            ...    ${row}
            ...    Status=${error_message}
        END
    ELSE
        Set To Dictionary
        ...    ${row}
        ...    Status=Purchase Order sent by BizTalk
    END
    RETURN    ${row}      ${error_message}

Send_PO_PDF
    [Arguments]    ${row}
    Sleep    5s
    RPA.Desktop.Press Keys      alt
    Sleep    0.5s
    RPA.Desktop.Press Keys      p
    Sleep    0.5s
    RPA.Desktop.Press Keys      a
    Sleep    1s
    Press Custom Combination    ctrl    enter
    Sleep    2s
    ${error_message}=       Set Variable    None
    RPA.Desktop.Clear Clipboard
    ${erro_popup}=    Run Keyword And Return Status
    ...    Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png    timeout=3
    IF    ${erro_popup}
        RPA.Desktop.Clear Clipboard
        Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png    timeout=60
        RPA.Desktop.Click       image:${EXECDIR}${/}data${/}Images${/}Error_button_logo.png
        Sleep   5s
        Press Custom Combination    ctrl    c
        Sleep    2s
        ${error_message}=    RPA.Desktop.Get Clipboard Value
        ${error_message}=    Replace String    ${error_message}    \r\n    '' 
        IF      $error_message != '' 
            RPA.Desktop.Press Keys      enter
            IF    'already sent' in $error_message.lower().lower()
                Set To Dictionary
                ...    ${row}
                ...    Status=Sending not Possible, Order Already sent!
            ELSE
                Log To Console With Timestamp  Error message :- ${error_message}
                Set To Dictionary
                ...    ${row}
                ...    Status=${error_message}
            END
        END
    ELSE
        ${email_dialog_open}=    Run Keyword And Return Status     Wait for Element    image:${EXECDIR}${/}data${/}Images${/}emaileditor.png   timeout=100    interval=10
        RPA.Desktop.Clear Clipboard
        RPA.Desktop.Press Keys      ctrl    a
        RPA.Desktop.Press Keys      ctrl    c
        Sleep    1s
        ${error_message}=    RPA.Desktop.Get Clipboard Value
        log to console     Here is the email- ${error_message} ---
        IF  not ${email_dialog_open}
            ${result}=    Update PO Step    ${po}   9
            IF    ${result}
                Log To Console With Timestamp    Purchase order ${po} updated to Step 3 successfully.
            ELSE
                Log To Console With Timestamp    Failed to update purchase order ${po}.
            END
            Set To Dictionary
            ...    ${row}
            ...    Status=Outlook couldn’t be opened

        ELSE IF    $error_message != ''
            ${body}=    Set Variable    ${primary_config['eBody']}
            ${body}=     Format Plain Text     ${body} 
            Set Clipboard Value      ${body}
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}emaileditor.png
            Sleep    2s
            Wait For Element     image:${EXECDIR}${/}data${/}Images${/}ebody_page.png      10
            RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}ebody_page.png
            RPA.Desktop.Press Keys      ctrl    v
            Sleep     2s
            Wait for Element    image:${EXECDIR}${/}data${/}Images${/}send_email.png   timeout=100
            Sleep     2s
            RPA.Desktop.Highlight Elements    image:${EXECDIR}${/}data${/}Images${/}send_email.png
            Set To Dictionary
            ...    ${row}
            ...    Status=Email sent to the vendor.
        ELSE
            RPA.Desktop.Click       ${close_outlook}
            RPA.Desktop.Press Keys      enter
            Set To Dictionary
            ...    ${row}
            ...    Status=Vendor email address not found.
        END
    END

    RETURN      ${row}      ${error_message}

Open Order Page And PO
    [Arguments]     ${po}
    Activate Nav Window     Purchase Order RPA
    ${is_window_streched}=    Run keyword And Return Status     Wait for Element    ${window_streched}     10
    IF  not ${is_window_streched}
        Minimize Screen     Purchase Order RPA     Role Center
        Activate Nav Window     Purchase Order RPA      Role Center
    END
    ${if_role_button}=   Run Keyword and Return Status    Wait for Element    ${role_center}      timeout=20
    IF  not ${if_role_button}
        Wait For Element      ${back_button}     timeout=15
        RPA.Desktop.Click     ${back_button}
    END
    Wait for Element    ${role_center}      timeout=20
    RPA.Desktop.Click     ${role_center}
    Log To Console With Timestamp    Role Center Clicked
    RPA.Desktop.Type Text    ${primary_config['PurchaseOrderPath']}
    Sleep    2s
    RPA.Desktop.Press Keys      enter
    ${purchase_order_verify}=   Run Keyword and Return Status     Wait For Element    image:${EXECDIR}${/}data${/}Images${/}Purchase_Order_verify.png      timeout=10
    Sleep    2s
    RPA.Desktop.Press Keys    enter
    Sleep   2s
    Press Custom Combination    ctrl    shift   a
    RPA.Desktop.Press Keys    f3
    Press Custom Combination    ctrl    a
    RPA.Desktop.Press Keys    backspace
    RPA.Desktop.Type Text    ${po}
    Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Reference_button_PO_Step_23.png     timeout=60
    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Reference_button_PO_Step_23.png
    Press Custom Combination    ctrl    a
    Press Custom Combination    ctrl    shift   e

Open_And_Extract_PO_Data
    [Arguments]    ${po}      ${is_extract_all}=${True}
    Log To Console With Timestamp      Is Extract all value :- ${is_extract_all}
    Open Order Page And PO      ${po}
    Activate Nav Window     Edit - Purchase Order      VTA
    Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Leading_profit_center_29_2_3.png     timeout=100
    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Leading_profit_center_29_2_3.png
    RPA.Desktop.Clear Clipboard
    RPA.Desktop.Press Keys      left
    Press Custom Combination    ctrl    a
    Sleep   2s
    Press Custom Combination    ctrl    c
    Sleep   2s
    ${leading_pc}=    RPA.Desktop.Get Clipboard Value
    IF    not ${is_extract_all}
        RETURN      ${leading_pc}
    END
    RPA.Desktop.Clear Clipboard
    Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Your_reference_29_2_4.png     timeout=100
    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Your_reference_29_2_4.png
    RPA.Desktop.Press Keys      left
    Press Custom Combination    ctrl    a
    Sleep   2s
    Press Custom Combination    ctrl    c
    Sleep   2s
    ${your_ref}=    RPA.Desktop.Get Clipboard Value
    Log To Console With Timestamp      Value fo your ref ${your_ref}
    ${is_mrp}=    Evaluate    $your_ref == "MRP"
    ${is_rework}=    Set Variable    False
    Wait For Element     image:${EXECDIR}${/}data${/}Images${/}Buy_from_vendor_29_2_6.png     timeout=100
    RPA.Desktop.Click    image:${EXECDIR}${/}data${/}Images${/}Buy_from_vendor_29_2_6.png
    RPA.Desktop.Clear Clipboard
    Sleep   0.5s
    RPA.Desktop.Press Keys      left
    Press Custom Combination    ctrl    a
    Sleep   1s
    Press Custom Combination    ctrl    c
    Sleep   1s
    ${vendor}=    RPA.Desktop.Get Clipboard Value
    RETURN    ${leading_pc}    ${is_mrp}    ${is_rework}    ${vendor}

Calculate Expected Receipt Date
    [Arguments]    ${requested_date}    ${priority}
    ${days_air}=    Set Variable     ${primary_config['DaysToCalcDeliveryAir']}
    ${days_normal}=     Set Variable    ${primary_config['DaysToCalcDelivery']}
    ${priority}=    Strip String    ${priority}
    ${priority}=    Convert To Upper Case    ${priority}
    IF    '${priority}' == 'HIGH'
        ${days_to_subtract}=    Set Variable    ${days_air}
    ELSE
        ${days_to_subtract}=    Set Variable    ${days_normal}
    END
    ${requested_date}=    Strip String    ${requested_date}
    IF    '${requested_date}' == ''
        RETURN    EMPTY
    END
    ${expected_date}=    Evaluate
    ...    (datetime.datetime.strptime("${requested_date}", "%d.%m.%Y")-datetime.timedelta(days=${days_to_subtract})).strftime("%d.%m.%Y")
    ...    modules=datetime
    RETURN    ${expected_date}



Log To Console With Timestamp
    [Documentation]    Logs message to console with timestamp prefix
    [Arguments]    ${message}
    ${timestamp}=    DateTime.Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Log To Console    [${timestamp}] ${message}


NAV Set Log Transactions
    [Arguments]    ${total}
    ${lib}=    Get Library Instance    RobotProcessLibrary
    Evaluate    setattr($lib.config, 'Log_Transactions', str(${total}))
    Log To Console    NAV Log_Transactions set to: ${total}

NAV Increment Done And Technically Checked
    ${lib}=    Get Library Instance    RobotProcessLibrary
    ${new_done}=    Evaluate    int($lib.config.Log_Done) + 1
    ${new_loop}=    Evaluate    int($lib.config.Log_Looping) + 1
    Evaluate    setattr($lib.config, 'Log_Done', str(${new_done}))
    Evaluate    setattr($lib.config, 'Log_Looping', str(${new_loop}))
    Log To Console    NAV Completed: ${new_done} | TechnicallyChecked: ${new_loop}

NAV Increment Technically Checked
    ${lib}=    Get Library Instance    RobotProcessLibrary
    ${new_loop}=    Evaluate    int($lib.config.Log_Looping) + 1
    Evaluate    setattr($lib.config, 'Log_Looping', str(${new_loop}))
    Log To Console    NAV TechnicallyChecked: ${new_loop}