
import pyodbc
from robot.api import logger
from robot.api.deco import keyword
from Resources.Config import Config

class db_adapters:
    """
    Simple DB Adapter for RPA0024-VTI
    """

    def __init__(self):
        """Initialize with connection string from Config.py in same directory"""
        self.connection_string = self._load_connection_string()
    
    def _load_connection_string(self):
        try:
            cfg = Config()
            CONNECTION_STRING = cfg.ConnectionString
            logger.console("✓ Connection string loaded from Config.py")
            logger.console(CONNECTION_STRING)
            return CONNECTION_STRING
        except ImportError as e:
            logger.warn(f"⚠ Config.py not found - using fallback connection string: {e}")
            fallback = (
                "Driver={SQL Server};Server=itlsqlotherscons;Database=UIPath_Param;Integrated Security=True"
            )
            logger.warn("⚠ Config.py not found - using fallback connection string")
            return fallback

    def _get_connection(self):
        """
        Establishes and returns database connection
        Returns None if connection fails
        """
        if not self.connection_string:
            logger.error("❌ No connection string available")
            return None
        
        try:
            conn = pyodbc.connect(self.connection_string)
            logger.info("✓ Database connection established")
            return conn
        except pyodbc.Error as e:
            logger.error(f"❌ Database connection failed: {e}")
            logger.error(f"Connection string: {self.connection_string}")
            return None


    # ============================================================
    # MAIN FUNCTION (YOUR REQUIREMENT)
    # ============================================================

    @keyword("Get PO Step")
    def get_po_step(self, purchase_order):
        """
        Fetch PurchaseOrder, Step, OutlookError
        """

        conn = self._get_connection()
        if not conn:
            return None

        try:
            cursor = conn.cursor()

            query = """
                SELECT [PurchaseOrder], [Step], [OutlookError]
                FROM [UIPath_Param].[dbo].[tb_RPA0024-VTI]
                WHERE [PurchaseOrder] = ?
            """

            cursor.execute(query, (purchase_order,))
            row = cursor.fetchone()

            if row:
                po = row[0]
                step = str(row[1])
                error = row[2]

                logger.info(f"PO={po}, Step={step}")

                return step
            else:
                logger.warn(f"No record found for PO: {purchase_order}")
                return None

        except Exception as e:
            logger.error(f"❌ Error fetching PO Step: {e}")
            return None

        finally:
            conn.close()


    @keyword("Insert PO Step")
    def insert_po_step(self, purchase_order, step ,process_id_code="RPA0024-VTI"):
        """
        Insert PurchaseOrder and Step into the corresponding table based on ProcessIDCode.
        The Step is set to '1' by default.
        """
        # Establish connection to the database
        conn = self._get_connection()
        if not conn:
            return None

        try:
            cursor = conn.cursor()
            # Define the dynamic table name using the ProcessIDCode
            table_name = f"tb_{process_id_code}"
            # Prepare the SQL query with placeholders
            query = f"""
            IF EXISTS (
                SELECT 1 FROM [{table_name}] WHERE PurchaseOrder = ?
            )
                UPDATE [{table_name}] SET Step = ? WHERE PurchaseOrder = ?
            ELSE
                INSERT INTO [{table_name}] (PurchaseOrder, Step)
                VALUES (?,?)
            """
            cursor.execute(query, (purchase_order, step, purchase_order, purchase_order, step))

            # Commit the transaction to save changes to the database
            conn.commit()

            # Log success
            logger.info(f"PO {purchase_order} inserted into {table_name} with Step 1")

            return True  # Return True if the insertion was successful

        except Exception as e:
            # Log the error if something goes wrong
            logger.error(f"❌ Error inserting PO Step: {e}")
            return False  # Return False if there was an error

        finally:
            # Close the database connection
            conn.close()


    @keyword("Update PO Step")
    def update_po_step(self, purchase_order, step, process_id_code="RPA0024-VTI"):
        """
        Update the Step to a dynamic value for the given PurchaseOrder in the corresponding table based on ProcessIDCode.
        The Step value is passed as a parameter.
        """

        # Establish connection to the database
        conn = self._get_connection()
        if not conn:
            return None

        try:
            cursor = conn.cursor()

            # Define the dynamic table name using the ProcessIDCode
            table_name = f"tb_{process_id_code}"

            # Prepare the SQL query with placeholders
            query = f"""
                UPDATE [{table_name}]
                SET Step = ?
                WHERE PurchaseOrder = ?
            """

            # Execute the query with the given purchase order and dynamic step value
            cursor.execute(query, (step, purchase_order))

            # Commit the transaction to save changes to the database
            conn.commit()

            # Log success
            logger.info(f"PO {purchase_order} updated to Step {step} in {table_name}")

            return True  # Return True if the update was successful

        except Exception as e:
            # Log the error if something goes wrong
            logger.error(f"❌ Error updating PO Step: {e}")
            return False  # Return False if there was an error

        finally:
            # Close the database connection
            conn.close()
        
    
    
    
    # ============================================================
    # TEST CONNECTION
    # ============================================================

    @keyword("Test DB Connection")
    def test_connection(self):
        conn = self._get_connection()
        if not conn:
            return False

        try:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchone()
            logger.info("✓ DB Connection OK")
            return True
        except Exception as e:
            logger.error(f"❌ Connection test failed: {e}")
            return False
        finally:
            conn.close()