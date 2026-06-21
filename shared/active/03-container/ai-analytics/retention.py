#!/usr/bin/env python3
"""
Data Retention and Pruning System for AI Analytics Pipeline
Handles automated data retention policies and pruning of old data
"""

import sqlite3
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, List


class RetentionPolicy:
    """Represents a data retention policy"""
    
    def __init__(self, table_name: str, date_column: str, retention_days: int, 
                 description: str = ""):
        self.table_name = table_name
        self.date_column = date_column
        self.retention_days = retention_days
        self.description = description
    
    def get_cutoff_date(self) -> str:
        """Get the cutoff date for this retention policy"""
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        return cutoff.isoformat()


class RetentionManager:
    """Manages data retention and pruning"""
    
    # Default retention policies
    DEFAULT_POLICIES = [
        RetentionPolicy("request_events", "timestamp", 90, 
                       "Request events older than 90 days"),
        RetentionPolicy("subagent_events", "start_time", 90,
                       "Subagent events older than 90 days"),
        RetentionPolicy("tool_events", "start_time", 90,
                       "Tool events older than 90 days"),
        RetentionPolicy("file_events", "created_at", 90,
                       "File events older than 90 days"),
        RetentionPolicy("cache_events", "created_at", 30,
                       "Cache events older than 30 days"),
        RetentionPolicy("skill_events", "start_time", 90,
                       "Skill events older than 90 days"),
        RetentionPolicy("daily_metrics", "metric_date", 365,
                       "Daily metrics older than 1 year"),
        RetentionPolicy("time_series_data", "timestamp", 180,
                       "Time series data older than 6 months"),
        RetentionPolicy("tool_heatmaps", "period_end", 180,
                       "Tool heatmaps older than 6 months"),
        RetentionPolicy("file_heatmaps", "period_end", 180,
                       "File heatmaps older than 6 months"),
        RetentionPolicy("cache_statistics", "period_end", 180,
                       "Cache statistics older than 6 months"),
    ]
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.conn = None
        self.policies = self.DEFAULT_POLICIES.copy()
    
    def connect(self):
        """Establish database connection"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
    
    def add_policy(self, policy: RetentionPolicy):
        """Add a custom retention policy"""
        self.policies.append(policy)
    
    def get_table_row_count(self, table_name: str) -> int:
        """Get the current row count for a table"""
        cursor = self.conn.cursor()
        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        return cursor.fetchone()[0]
    
    def prune_table(self, policy: RetentionPolicy, dry_run: bool = True) -> Dict:
        """Prune data from a table based on retention policy"""
        cursor = self.conn.cursor()
        
        cutoff_date = policy.get_cutoff_date()
        
        # Get current row count
        current_count = self.get_table_row_count(policy.table_name)
        
        # Count rows to be deleted
        count_query = f"""
            SELECT COUNT(*) FROM {policy.table_name}
            WHERE {policy.date_column} < '{cutoff_date}'
        """
        cursor.execute(count_query)
        rows_to_delete = cursor.fetchone()[0]
        
        result = {
            "table": policy.table_name,
            "current_count": current_count,
            "rows_to_delete": rows_to_delete,
            "cutoff_date": cutoff_date,
            "deleted": False
        }
        
        if rows_to_delete > 0 and not dry_run:
            # Perform the deletion
            delete_query = f"""
                DELETE FROM {policy.table_name}
                WHERE {policy.date_column} < '{cutoff_date}'
            """
            cursor.execute(delete_query)
            self.conn.commit()
            result["deleted"] = True
        
        return result
    
    def prune_all(self, dry_run: bool = True) -> List[Dict]:
        """Prune data from all tables based on retention policies"""
        results = []
        
        for policy in self.policies:
            try:
                result = self.prune_table(policy, dry_run)
                results.append(result)
            except Exception as e:
                print(f"Error pruning {policy.table_name}: {e}")
                results.append({
                    "table": policy.table_name,
                    "error": str(e)
                })
        
        return results
    
    def analyze_storage(self) -> Dict:
        """Analyze current database storage usage"""
        cursor = self.conn.cursor()
        
        # Get database file size
        db_size = os.path.getsize(self.db_path)
        
        # Get row counts for all tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        table_stats = {}
        total_rows = 0
        
        for table in tables:
            table_name = table[0]
            if table_name == "schema_migrations":
                continue
            
            count = self.get_table_row_count(table_name)
            table_stats[table_name] = count
            total_rows += count
        
        return {
            "db_size_bytes": db_size,
            "db_size_mb": db_size / (1024 * 1024),
            "total_rows": total_rows,
            "table_stats": table_stats
        }
    
    def vacuum_database(self) -> bool:
        """Vacuum the database to reclaim space"""
        try:
            cursor = self.conn.cursor()
            cursor.execute("VACUUM")
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Error vacuuming database: {e}")
            return False
    
    def run_retention(self, dry_run: bool = False, vacuum: bool = False) -> bool:
        """Run the full retention process"""
        try:
            self.connect()
            
            print("=" * 60)
            print("Data Retention and Pruning")
            print("=" * 60)
            
            # Analyze current storage
            print("\nCurrent Storage Analysis:")
            storage = self.analyze_storage()
            print(f"  Database size: {storage['db_size_mb']:.2f} MB")
            print(f"  Total rows: {storage['total_rows']:,}")
            
            print("\nTable Statistics:")
            for table, count in storage['table_stats'].items():
                print(f"  {table}: {count:,} rows")
            
            # Run pruning
            print("\n" + "=" * 60)
            if dry_run:
                print("DRY RUN - No data will be deleted")
            else:
                print("PRUNING - Data will be permanently deleted")
            print("=" * 60)
            
            results = self.prune_all(dry_run=dry_run)
            
            total_deleted = 0
            for result in results:
                if "error" in result:
                    print(f"  ✗ {result['table']}: {result['error']}")
                else:
                    if result['rows_to_delete'] > 0:
                        status = "Would delete" if dry_run else "Deleted"
                        print(f"  ✓ {result['table']}: {status} {result['rows_to_delete']:,} rows (cutoff: {result['cutoff_date']})")
                        total_deleted += result['rows_to_delete']
                    else:
                        print(f"  ○ {result['table']}: No rows to delete")
            
            print(f"\nTotal rows to delete: {total_deleted:,}")
            
            # Vacuum if requested and not dry run
            if vacuum and not dry_run and total_deleted > 0:
                print("\nVacuuming database to reclaim space...")
                if self.vacuum_database():
                    print("✓ Database vacuumed successfully")
                    
                    # Show new size
                    new_storage = self.analyze_storage()
                    space_saved = storage['db_size_mb'] - new_storage['db_size_mb']
                    print(f"  Space saved: {space_saved:.2f} MB")
                    print(f"  New size: {new_storage['db_size_mb']:.2f} MB")
            
            print("\n" + "=" * 60)
            if dry_run:
                print("Dry run complete. Run without --dry-run to actually delete data.")
            else:
                print("Retention process complete.")
            print("=" * 60)
            
            return True
            
        except Exception as e:
            print(f"Retention process failed: {e}")
            return False
        finally:
            self.close()
    
    def get_retention_config(self) -> Dict:
        """Get current retention configuration from database"""
        cursor = self.conn.cursor()
        
        cursor.execute("""
            SELECT config_key, config_value, config_type, description
            FROM configuration
            WHERE config_key LIKE 'retention_%'
        """)
        
        config = {}
        for row in cursor.fetchall():
            key = row['config_key'].replace('retention_', '')
            value = row['config_value']
            config_type = row['config_type']
            
            # Convert value based on type
            if config_type == 'number':
                value = int(value)
            elif config_type == 'boolean':
                value = value.lower() == 'true'
            
            config[key] = {
                'value': value,
                'type': config_type,
                'description': row['description']
            }
        
        return config
    
    def update_retention_config(self, key: str, value: str, value_type: str, 
                               description: str = "") -> bool:
        """Update retention configuration in database"""
        cursor = self.conn.cursor()
        
        try:
            config_key = f"retention_{key}"
            
            cursor.execute("""
                INSERT OR REPLACE INTO configuration 
                (config_key, config_value, config_type, description, updated_at)
                VALUES (?, ?, ?, ?, ?)
            """, (config_key, value, value_type, description, datetime('isoformat')))
            
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Error updating retention config: {e}")
            self.conn.rollback()
            return False


def main():
    """Main entry point"""
    import argparse
    
    # Default path
    script_dir = Path(__file__).parent
    default_db = str(script_dir / "analytics.db")
    
    parser = argparse.ArgumentParser(description="Data Retention and Pruning System")
    parser.add_argument("--db", default=default_db, help="Database file path")
    parser.add_argument("command", choices=["prune", "analyze", "config"], 
                       help="Command to execute")
    parser.add_argument("--dry-run", action="store_true", help="Dry run without deleting")
    parser.add_argument("--vacuum", action="store_true", help="Vacuum database after pruning")
    parser.add_argument("--table", help="Specific table to prune")
    parser.add_argument("--days", type=int, help="Custom retention days")
    parser.add_argument("--config-key", help="Configuration key to set")
    parser.add_argument("--config-value", help="Configuration value to set")
    parser.add_argument("--config-type", choices=["string", "number", "boolean"], 
                       help="Configuration value type")
    
    args = parser.parse_args()
    
    manager = RetentionManager(args.db)
    
    if args.command == "prune":
        success = manager.run_retention(dry_run=args.dry_run, vacuum=args.vacuum)
        sys.exit(0 if success else 1)
    elif args.command == "analyze":
        try:
            manager.connect()
            storage = manager.analyze_storage()
            
            print("Database Storage Analysis")
            print("=" * 60)
            print(f"Database size: {storage['db_size_mb']:.2f} MB")
            print(f"Total rows: {storage['total_rows']:,}")
            print("\nTable Statistics:")
            for table, count in storage['table_stats'].items():
                print(f"  {table}: {count:,} rows")
            
            manager.close()
        except Exception as e:
            print(f"Analysis failed: {e}")
            sys.exit(1)
    elif args.command == "config":
        try:
            manager.connect()
            
            if args.config_key and args.config_value and args.config_type:
                # Set configuration
                success = manager.update_retention_config(
                    args.config_key, args.config_value, args.config_type
                )
                if success:
                    print(f"✓ Updated retention config: {args.config_key} = {args.config_value}")
                else:
                    print("✗ Failed to update config")
                    sys.exit(1)
            else:
                # Show current configuration
                config = manager.get_retention_config()
                print("Current Retention Configuration")
                print("=" * 60)
                for key, info in config.items():
                    print(f"  {key}: {info['value']} ({info['type']})")
                    if info['description']:
                        print(f"    Description: {info['description']}")
            
            manager.close()
        except Exception as e:
            print(f"Config operation failed: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()
