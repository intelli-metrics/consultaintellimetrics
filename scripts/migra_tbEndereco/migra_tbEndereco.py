import psycopg2
from psycopg2.extras import DictCursor
import os
from dotenv import load_dotenv
import csv
from datetime import datetime
import argparse

# Load environment variables
load_dotenv()

# Database connection parameters
DB_PARAMS = {
    'dbname': os.getenv('DB_DATABASE'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT')
}

def setup_logging(dry_run=False):
    """Setup logging directory and files"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_dir = 'logs'
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = os.path.join(log_dir, f'migration_{timestamp}.log')
    csv_file = os.path.join(log_dir, f'processed_addresses_{timestamp}.csv')
    
    return log_file, csv_file

def log_message(log_file, message):
    """Log a message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, 'a') as f:
        f.write(f'[{timestamp}] {message}\n')
    print(f'[{timestamp}] {message}')

def get_unique_addresses(cursor, table_name, log_file):
    """Get unique addresses from a table"""
    log_message(log_file, f"Fetching unique addresses from {table_name}")
    
    if table_name == 'TbPosicao':
        query = f"""
        SELECT DISTINCT 
            "dsEndereco" as "dsLogradouro",
            "dsNum" as "nrNumero",
            NULL as "dsComplemento",
            "dsBairro",
            "dsCep",
            "dsCidade",
            "dsUF",
            "dsLat",
            "dsLong"
        FROM "{table_name}"
        WHERE "dsLat" IS NOT NULL
        """
    else:
        query = f"""
        SELECT DISTINCT 
            "dsLogradouro",
            "nrNumero",
            "dsComplemento",
            "dsBairro",
            "dsCep",
            "dsCidade",
            "dsUF",
            "dsLat",
            "dsLong"
        FROM "{table_name}"
        WHERE "dsLat" IS NOT NULL
        """
    
    cursor.execute(query)
    addresses = cursor.fetchall()
    log_message(log_file, f"Found {len(addresses)} unique addresses in {table_name}")
    return addresses

def write_to_csv(csv_file, addresses, source_table):
    """Write processed addresses to CSV"""
    fieldnames = [
        'source_table', 'dsLogradouro', 'nrNumero', 'dsComplemento',
        'dsBairro', 'dsCep', 'dsCidade', 'dsUF', 'dsLat', 'dsLong'
    ]
    
    file_exists = os.path.isfile(csv_file)
    
    with open(csv_file, 'a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not file_exists:
            writer.writeheader()
        
        for addr in addresses:
            row = {
                'source_table': source_table,
                'dsLogradouro': addr['dsLogradouro'],
                'nrNumero': addr['nrNumero'],
                'dsComplemento': addr['dsComplemento'],
                'dsBairro': addr['dsBairro'],
                'dsCep': addr['dsCep'],
                'dsCidade': addr['dsCidade'],
                'dsUF': addr['dsUF'],
                'dsLat': addr['dsLat'],
                'dsLong': addr['dsLong']
            }
            writer.writerow(row)

def main():
    parser = argparse.ArgumentParser(description='Migrate addresses to TbEndereco')
    parser.add_argument('--dry-run', action='store_true', help='Run in dry-run mode (no changes will be made)')
    args = parser.parse_args()

    log_file, csv_file = setup_logging(args.dry_run)
    log_message(log_file, f"Starting migration {'(DRY RUN)' if args.dry_run else ''}")

    try:
        # Connect to the database
        conn = psycopg2.connect(**DB_PARAMS)
        # Set autocommit before any operations
        conn.autocommit = True
        cursor = conn.cursor(cursor_factory=DictCursor)
        log_message(log_file, "Connected to database successfully")

        # Get unique addresses from both tables
        posicao_addresses = get_unique_addresses(cursor, 'TbPosicao', log_file)
        destinatario_addresses = get_unique_addresses(cursor, 'TbDestinatario', log_file)

        # Write addresses to CSV
        write_to_csv(csv_file, posicao_addresses, 'TbPosicao')
        write_to_csv(csv_file, destinatario_addresses, 'TbDestinatario')
        log_message(log_file, f"Addresses written to {csv_file}")

        # Combine and deduplicate addresses
        all_addresses = set()
        for addr in posicao_addresses + destinatario_addresses:
            addr_tuple = (
                addr['dsLogradouro'],
                addr['nrNumero'],
                addr['dsComplemento'],
                addr['dsBairro'],
                addr['dsCep'],
                addr['dsCidade'],
                addr['dsUF'],
                addr['dsLat'],
                addr['dsLong']
            )
            all_addresses.add(addr_tuple)
        
        log_message(log_file, f"Total unique addresses to process: {len(all_addresses)}")

        if not args.dry_run:
            # Start transaction for the last three steps
            conn.autocommit = False
            try:
                # 1. Insert unique addresses into "TbEndereco"
                inserted_count = 0
                for addr in all_addresses:
                    cursor.execute("""
                        INSERT INTO "TbEndereco" (
                            "dsLogradouro", "nrNumero", "dsComplemento", "dsBairro",
                            "dsCep", "dsCidade", "dsUF", "dsLat", "dsLong"
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT DO NOTHING
                        RETURNING "cdEndereco"
                    """, addr)
                    if cursor.rowcount > 0:
                        inserted_count += 1
                
                log_message(log_file, f"Inserted {inserted_count} new addresses into TbEndereco")

                # 2. Update TbPosicao with new cdEndereco
                cursor.execute("""
                    UPDATE "TbPosicao" p
                    SET "cdEndereco" = e."cdEndereco"
                    FROM "TbEndereco" e
                    WHERE p."dsLat" = e."dsLat"
                    AND p."dsLong" = e."dsLong"
                    RETURNING p."cdPosicao"
                """)
                posicao_updated = cursor.rowcount
                log_message(log_file, f"Updated {posicao_updated} records in TbPosicao")

                # 3. Update TbDestinatario with new cdEndereco
                cursor.execute("""
                    UPDATE "TbDestinatario" d
                    SET "cdEndereco" = e."cdEndereco"
                    FROM "TbEndereco" e
                    WHERE d."dsLat" = e."dsLat"
                    AND d."dsLong" = e."dsLong"
                    RETURNING d."cdDestinatario"
                """)
                destinatario_updated = cursor.rowcount
                log_message(log_file, f"Updated {destinatario_updated} records in TbDestinatario")

                # Commit the transaction
                conn.commit()
                log_message(log_file, "Migration completed successfully!")

            except Exception as e:
                conn.rollback()
                log_message(log_file, f"Error during migration: {str(e)}")
                raise
        else:
            log_message(log_file, "Dry run completed - no changes were made to the database")

    except Exception as e:
        log_message(log_file, f"Database connection error: {str(e)}")
        raise

    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
        log_message(log_file, "Database connection closed")

if __name__ == "__main__":
    main()

