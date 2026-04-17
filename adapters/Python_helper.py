import os
import csv
import pyautogui
import time
from collections import defaultdict
from robot.api import logger
import pygetwindow as gw
import pyperclip
import re
from collections import defaultdict
import html
import re
import pyperclip

def format_plain_text(body_text):

    if isinstance(body_text, list):
        merged = []

        for item in body_text:
            # item can be tuple or string
            if isinstance(item, (list, tuple)):
                merged.append(str(item[0]))
            else:
                merged.append(str(item))

        body_text = " ".join(merged)

    else:
        body_text = str(body_text)

    # DEBUG
    print("MERGED:", body_text)

    body_text = body_text.strip('"').strip('[]')

    body_text = body_text.replace("//", "\n\n")   # paragraph
    body_text = body_text.replace("/", "\n")      # line break

    body_text = "\n".join(line.strip() for line in body_text.splitlines())

    return body_text

def copy_with_headers():
    time.sleep(4)
    pyautogui.keyDown('ctrl')
    pyautogui.keyDown('shift')
    pyautogui.press('c')
    pyautogui.keyUp('shift')
    pyautogui.keyUp('ctrl')

def clear_clipboard():
    pyperclip.copy("")
    logger.console("Clipboard Cleared")

def extract_nav_details(nav_table):
    if not nav_table:
        return "", "", ""
    row = nav_table[0]
    indent_no = row.get("No.", "")
    priority = row.get("Priority", "")
    profit_center = row.get("Leading Profitcenter", "")
    return indent_no, priority, profit_center

def write_table_to_csv(data, path):
    if not data:
        return
    keys = data[0].keys()
    with open(path, 'w', newline='', encoding='utf-8') as output_file:
        dict_writer = csv.DictWriter(output_file, fieldnames=keys)
        dict_writer.writeheader()
        dict_writer.writerows(data)

def merge_indent_and_po_tables(grouped_table, po_table):
    merged = []
    for row in grouped_table:
        new_row = dict(row)
        new_row["Purchase Name"] = ""
        new_row["Assigned User ID"] = ""
        merged.append(new_row)
    for row in po_table:
        new_row = dict(row)
        new_row["Purchase Name"] = ""
        new_row["Assigned User ID"] = ""
        merged.append(new_row)
    return merged

def group_indent_lines(rows):
    grouped = defaultdict(list)
    for row in rows:
        key = (row.get("Vendor No."), row.get("Priority"))
        grouped[key].append(row)
    result = []
    for (vendor, priority), items in grouped.items():
        result.append({
            "DocumentType": "Indent",
            "Document No.": "",
            "Indent Reference/Status": "Indents Lines grouped by Vendor",
            "Priority": priority,
            "ProfitCenter": items[0].get("ProfitCenter", ""),
            "Vendor No.": vendor,
            "Due Date": items[0].get("Due Date", ""),
            "Status": items[0].get("Document No.", "")
        })
    return result

def press_custom_combination(*keys):
    time.sleep(0.5)
    for key in keys:
        pyautogui.keyDown(key.lower())
    for key in reversed(keys):
        pyautogui.keyUp(key.lower())

def extract_and_save_po_table(file_path):
    raw_data = pyperclip.paste()
    if not raw_data.strip():
        raise Exception("Clipboard is empty")
    lines = raw_data.splitlines()
    table = []
    header = None
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        row = [col.strip() for col in line.split(",")]
        if header is None:
            header = row
            table.append(dict(zip(header, header)))
            continue
        if len(row) == len(header):
            table.append(dict(zip(header, row)))
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        for row in table[1:]:
            writer.writerow(row)
    return table[1:], file_path

def save_clipboard_table(data, folder_path, file_name):
    if not data or not data.strip():
        raise ValueError("Clipboard is empty")
    logger.console(f"Here in fodler_path and printing {folder_path} - {file_name}")
    os.makedirs(folder_path, exist_ok=True)
    file_path = os.path.join(folder_path, file_name)
    lines = data.strip().splitlines()
    headers = [h.strip() for h in lines[0].split("\t")]
    raw_table = []
    logger.console(file_path)
    with open(file_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for line in lines:
            row = [cell.strip() for cell in line.split("\t")]
            writer.writerow(row)
        for line in lines[1:]:
            values = [cell.strip() for cell in line.split("\t")]
            row_dict = dict(zip(headers, values))
            raw_table.append(row_dict)
    logger.console(f"Here is the file path :- {file_path}")
    return raw_table, file_path

def normalize_indent_table_indent_rpa(raw_table):
    normalized = []
    for row in raw_table:
        doc_type = row.get("DocumentType", "").strip()
        if not doc_type:
            doc_type = "Indent"
        new_row = {
            "DocumentType": doc_type,
            "DocumentNo": row.get("DocumentNo", "").strip(),
            "Indent Reference/Status": row.get("Indent Reference/Status", "").strip(),
            "Priority": row.get("Priority", "").strip(),
            "ProfitCenter": row.get("ProfitCenter", "").strip(),
            "Vendor No": row.get("Vendor No", "").strip(),
            "Due Date": row.get("Due Date", "").strip(),
            "Status": row.get("Status", "").strip()
        }
        normalized.append(new_row)
    return normalized

def extract_vendor_empty(indent_table):
    vendor_empty_table = []
    for row in indent_table:
        if not row.get("Vendor No", "").strip():
            vendor_empty_table.append({
                "DocumentNo": row.get("DocumentNo", ""),
                "Priority": row.get("Priority", ""),
                "Due Date": row.get("Due Date", ""),
                "ProfitCenter": row.get("ProfitCenter", "")
            })
    return vendor_empty_table

def remove_vendor_empty(indent_table):
    filtered_table = []
    for row in indent_table:
        if row.get("Vendor No", "").strip():
            filtered_table.append(row)
    return filtered_table

def process_indent_lines(indent_line_table, indent_table, vendor_empty_table):
    indent_lookup = {row["DocumentNo"]: row for row in indent_table}
    vendor_empty_lookup = {row["DocumentNo"]: row for row in vendor_empty_table}
    processed_lines = []
    error_table = []

    for row in indent_line_table:
        document_no = row.get("DocumentNo", "").strip()
        row["Priority"] = ""
        row["ProfitCenter"] = ""
        row["Type"] = ""
        
        if document_no in indent_lookup:
            row["Type"] = "DELETE"
        
        if document_no in vendor_empty_lookup:
            vendor_data = vendor_empty_lookup[document_no]
            row["Priority"] = vendor_data.get("Priority", "")
            row["Due Date"] = vendor_data.get("Due Date", "")
            row["ProfitCenter"] = (
                vendor_data.get("ProfitCenter")
                or vendor_data.get("Leading Profitcenter")
                or ""
            )

        # Check for missing Vendor No.
        if not row.get("Vendor No.", "").strip():
            logger.console(f"Error: Missing Vendor No. in row with Document No: {row.get('DocumentNo')}")
            error_table.append({
                "Document No": row.get("DocumentNo", ""),
                "No.": row.get("No.", ""),
                "Description": row.get("Description", ""),
                "Vendor No.": row.get("Vendor No.", ""),
                "Due Date": row.get("Due Date", ""),
                "Error": "Missing Vendor No. in Indent Header and Indent Line"
            })
        
        processed_lines.append(row)

    # Remove rows with "DELETE" type or empty Vendor No.
    final_indent_lines = [
        row for row in processed_lines
        if row.get("Type") != "DELETE" and row.get("Vendor No", "").strip()
    ]

    # Sort the final lines by Document No.
    final_indent_lines = sorted(final_indent_lines, key=lambda x: x.get("DocumentNo", ""))

    # Return both the filtered indent lines and the error table
    return final_indent_lines, error_table

def check_window_responsive(timeout=120):
    start = time.time()
    while True:
        if time.time() - start > timeout:
            raise TimeoutError("No responsive window found within timeout")
        for title in gw.getAllTitles():
            if title and "Not Responding" not in title:
                return title
        time.sleep(2)

def close_nav_window():
    for window in gw.getAllWindows():
        title = window.title
        if "VTI Testsystem" in title or "VTI Livesystem" in title or "MSNAV" in title:
            window.close()

def Close_existing_navision():
    for window in gw.getAllWindows():
        title = window.title
        if "VTI Testsystem" in title or "VTI Livesystem" in title or "MSNAV" in title:
            window.close()

def activate_nav_window(name="Role Center", role="VTI Testsystem"):
    for window in gw.getAllWindows():
        title = window.title
        if name in title or role in title or "Role Center" in title or "Indents Line RPA" in title or "Purchase Orders RPA" in title and "- VTI" not in title and "-VTI" not in title:
            logger.console(f"Activating NAV window: {name} {role}")
            try:
                if window.isMinimized:
                    window.restore()
                    time.sleep(0.5)
                pyautogui.press('alt')
                time.sleep(0.2)
                window.activate()
                window.maximize()
                time.sleep(0.5)
                window.maximize()
                time.sleep(0.5)
            except Exception as e:
                logger.console(f"Activate failed: {e}")
            logger.console(f"Activated NAV window: {title}")
            break
    time.sleep(2)
def minimize_screen(name="Role Center", role="VTI Testsystem"):
    for window in gw.getAllWindows():
        title = window.title
        if name in title or role in title or "Role Center" in title or "Indents Line RPA" in title or "Purchase Orders RPA" in title and "- VTI" not in title and "-VTI" not in title:
            try:
                if window.isMinimized:
                    window.restore()
                    time.sleep(0.5)
                window.activate()
                time.sleep(0.5)
                window.minimize()
            except Exception as e:
                logger.console(f"Activate failed: {e}")
            logger.console(f"Activated NAV window: {title}")
            break
    time.sleep(2)
def activate_nav_window_msnav(name="Indent RPA", role="VTI Testsystem"):
    for window in gw.getAllWindows():
        title = window.title
        if name in title or role in title or "Role" in title or "Indents Line RPA" in title or "Purchase Orders RPA" in title or "Indent Line RPA" in title and "- VTI" not in title and "-VTI" not in title:
            logger.console(f"Activating NAV window: {name} {role}")
            try:
                if window.isMinimized:
                    window.restore()
                    time.sleep(0.5)
                pyautogui.press('alt')
                time.sleep(0.2)
                window.activate()
                window.maximize()
                time.sleep(0.5)
                window.maximize()
            except Exception as e:
                logger.console(f"Activate failed: {e}")
            logger.console(f"Activated NAV window: {title}")
            break
    time.sleep(2)

def activate_nav_window_msnav_max(name="Indent RPA", role="VTI Testsystem"):
    for window in gw.getAllWindows():
        title = window.title
        if name in title or role in title or "Role" in title or "Indents Line RPA" in title or "Purchase Orders RPA" in title or "Indent Line RPA" in title and "- VTI" not in title and "-VTI" not in title:
            logger.console(f"Activating NAV window: {name} {role}")
            try:
                if window.isMinimized:
                    window.restore()
                    time.sleep(0.5)
                time.sleep(0.2)
                window.activate()
                window.maximize()
                time.sleep(0.5)
                window.maximize()
   
            except Exception as e:
                logger.console(f"Activate failed: {e}")
            logger.console(f"Activated NAV window: {title}")
            break
    time.sleep(2)

def is_nav_running():
    logger.console("Checking if NAV is already running...")
    for title in gw.getAllTitles():
        if "MSNAV" in title or "Microsoft Dynamics NAV" in title or "NAV 2015" in title or 'VTI Testsystem' in title:
            window = gw.getWindowsWithTitle(title)[0]
            window.activate()
            logger.console(f"NAV window detected: {title}")
            return True
    logger.console("NAV window NOT detected")
    return False

def wait_for_nav_window(timeout=90):
    logger.console(f"Waiting for NAV window (timeout={timeout}s)...")
    end = time.time() + timeout
    while time.time() < end:
        for title in gw.getAllTitles():
            if "MSNAV" in title or "Microsoft Dynamics NAV" in title or "NAV 2015" in title:
                logger.console(f"NAV window appeared: {title}")
                return True
        time.sleep(2)
    logger.error("Timeout waiting for NAV window")
    return False

def open_latest_ica(timeout=60, poll_interval=1, max_age_seconds=180):
    logger.console("Waiting for new ICA file in Downloads...")
    downloads = os.path.join(os.path.expanduser("~"), "Downloads")
    start_time = time.time()
    while time.time() - start_time < timeout:
        now = time.time()
        ica_files = [
            os.path.join(downloads, f)
            for f in os.listdir(downloads)
            if f.lower().endswith(".ica")
        ]
        valid_files = []
        for file in ica_files:
            file_age = now - os.path.getctime(file)
            if file_age <= max_age_seconds:
                valid_files.append(file)
        if valid_files:
            latest_file = max(valid_files, key=os.path.getctime)
            logger.console(
                f"Opening ICA file: {os.path.basename(latest_file)} "
                f"(age: {int(now - os.path.getctime(latest_file))} sec)"
            )
            os.startfile(latest_file)
            return True
        time.sleep(poll_interval)
    logger.error("Timeout: No new ICA file detected within allowed age.")
    return False

def close_citrix_popup():
    logger.console("Closing Citrix protocol popup using ESC")
    time.sleep(3)
    pyautogui.press("esc")

def select_nav_environment(env_name="VTI - Test", max_moves=14):
    logger.console(f"Selecting NAV environment: {env_name}")
    for title in gw.getAllTitles():
        if "NAV" in title or "MSNAV" in title:
            gw.getWindowsWithTitle(title)[0].activate()
            logger.console(f"Activated NAV window: {title}")
            break
    time.sleep(1)
    pyautogui.typewrite(env_name, interval=0.08)
    for _ in range(max_moves):
        pyautogui.hotkey("ctrl", "c")
        selected = pyperclip.paste().strip()
        logger.console(f"Current selection: {selected}")
        if selected == env_name:
            logger.console("Exact environment match found. Confirming selection.")
            pyautogui.press("enter")
            return True
        pyautogui.press("down")
        time.sleep(0.2)
    pyautogui.press('enter')
    logger.error(f"Failed to find exact NAV environment: {env_name}")
    return False

def load_csv_unique_headers(file_path):
    logger.console("\n📂 Loading CSV: " + file_path)
    with open(file_path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    headers = rows[0]
    logger.console("Original Headers: " + str(headers))
    seen = defaultdict(int)
    unique_headers = []
    for h in headers:
        if seen[h] == 0:
            unique_headers.append(h)
        else:
            unique_headers.append(f"{h}_{seen[h]}")
        seen[h] += 1
    logger.console("Unique Headers: " + str(unique_headers))
    data_rows = rows[1:]
    table = []
    for row in data_rows:
        row_dict = dict(zip(unique_headers, row))
        table.append(row_dict)
    logger.console(f"Rows Loaded: {len(table)}")
    return table

def extract_po_number(doc_no):
    if not doc_no:
        return ""
    match = re.search(r"P\d+", doc_no)
    return match.group(0) if match else ""

def process_step_29_backend(table):
    logger.console("\n===== STEP 29 BACKEND START =====\n")
    total_rows = 0
    updated_count = 0
    for row in table:
        total_rows += 1
        document_no   = (row.get("DocumentNo") or "").strip()
        document_type = (row.get("DocumentType") or "").strip()
        vendor_no     = (row.get("Vendor No") or "").strip()
        profit_center = (row.get("ProfitCenter") or "").strip()
        priority      = (row.get("Priority") or "").strip().upper()
        for key in row:
            val = row[key]
            if isinstance(val, str) and val.strip().startswith("="):
                row[key] = ""
                logger.console(f"Cleaned Excel formula from column '{key}': {val}")
        document_no   = (row.get("DocumentNo") or "").strip()
        document_type = (row.get("DocumentType") or "").strip()
        vendor_no     = (row.get("Vendor No") or "").strip()
        profit_center = (row.get("ProfitCenter") or "").strip()
        priority      = (row.get("Priority") or "").strip().upper()
        logger.console("----------------------------------")
        logger.console(f"Row {total_rows}")
        logger.console(f"DocumentType: {document_type}")
        logger.console(f"DocumentNo: {document_no}")
        logger.console(f"Vendor No: {vendor_no}")
        logger.console(f"ProfitCenter: {profit_center}")
        logger.console(f"Priority: {priority}")
        if not document_no or document_no.lower() == "null":
            if document_type == "Indent":
                if not vendor_no or vendor_no.lower() == "null":
                    row["Status"] = "Indent without Vendor No"
                elif not profit_center or profit_center.lower() == "null":
                    row["Status"] = "Indent without ProfitCenter code"
                else:
                    row["Status"] = "Create a new purchase order"
            else:
                row["Status"] = "Purchase or Indent row is invalid."
        else:
            is_high_priority = priority == "HIGH"
            logger.console(f"High Priority: {is_high_priority}")
            row["Status"] = ""
        updated_count += 1
        logger.console(f"STATUS: {row.get('Status', '')}")
    logger.console("\n===== SUMMARY =====")
    logger.console(f"Total Rows: {total_rows}")
    logger.console(f"Rows Updated: {updated_count}")
    logger.console("===== STEP 29 BACKEND END =====\n")
    return table
