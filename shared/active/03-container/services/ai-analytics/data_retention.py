#!/usr/bin/env python3
"""
AI Analytics Pipeline - Data Retention and Pruning Script
Automatically prunes old data based on retention policies
"""

import sqlite3
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
import logging
from typing import Dict, List, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataRetentionManager:
    """Manages data retention and pruning operations"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.conn = None
        
    def connect(self):
        """Establish database connection"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        logger.info(f"Connected to database: {self.db_path}")
        
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
    
    def get_retention_config(self) -> Dict[str, int]:
        """Get retention configuration from database"""
        cursor = self.conn.cursor()
        
        config = {}
        retention_keys = [
            'retention.raw_events_days',
            'retention.aggregated_data_days',
            'retention.audit_log_days'
        ]
        
        for key in retention_keys:
            cursor.execute(
                "SELECT config_value FROM configuration WHERE config_key = ?",
                (key,)
            )
            row = cursor.fetchone()
            if row:
                try:
                    config[key] = int(row['config_value'])
                except ValueError:
                    logger.warning(f"Invalid retention value for {key}: {row['config_value']}")
                    config[key] = 30  # Default to 30 days
            else:
                logger.warning(f"Retention config not found for {key}, using default")
                config[key] = 30  # Default to 30 days
        
        return config
    
    def prune_raw_events(self, days: int, dry_run: bool = False) -> Tuple[int, int]:
        """Prune raw request/response events older than specified days"""
        cursor = self.conn.cursor()
        
        cutoff_date = datetime.now() - timedelta(days=days)
        cutoff_timestamp = cutoff_date.isoformat()
        
        logger.info(f"Pruning raw events older than {days} days (before {cutoff_timestamp})")
        
        # Count affected rows
        cursor.execute(
            "SELECT COUNT(*) as count FROM request_events WHERE timestamp < ?",
            (cutoff_timestamp,)
        )
        request_count = cursor.fetchone()['count']
        
        cursor.execute(
            "SELECT COUNT(*) as count FROM response_events WHERE timestamp < ?",
            (cutoff_timestamp,)
        )
        response_count = cursor.fetchone()['count']
        
        total_count = request_count + response_count
        
        if dry_run:
            logger.info(f"[DRY RUN] Would delete {request_count} request events and {response_count} response events")
            return (0, total_count)
        
        if total_count == 0:
            logger.info("No raw events to prune")
            return (0, 0)
        
        # Delete in transaction
        try:
            # Delete response events first (due to foreign key)
            cursor.execute(
                "DELETE FROM response_events WHERE timestamp < ?",
                (cutoff_timestamp,)
            )
            
            # Delete request events
            cursor.execute(
                "DELETE FROM request_events WHERE timestamp < ?",
                (cutoff_timestamp,)
            )
            
            self.conn.commit()
            logger.info(f"Deleted {request_count} request events and {response_count} response events")
            return (total_count, total_count)
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to prune raw events: {e}")
            return (0, 0)
    
    def prune_aggregated_data(self, days: int, dry_run: bool = False) -> Tuple[int, int]:
        """Prune aggregated data older than specified days"""
        cursor = self.conn.cursor()
        
        cutoff_date = datetime.now() - timedelta(days=days)
        cutoff_timestamp = cutoff_date.isoformat()
        
        logger.info(f"Pruning aggregated data older than {days} days (before {cutoff_timestamp})")
        
        # Count affected rows in aggregation tables
        tables_to_prune = [
            'hourly_aggregations',
            'daily_aggregations'
        ]
        
        total_count = 0
        counts = {}
        
        for table in tables_to_prune:
            cursor.execute(
                f"SELECT COUNT(*) as count FROM {table} WHERE timestamp_hour < ?" if table == 'hourly_aggregations'
                else f"SELECT COUNT(*) as count FROM {table} WHERE timestamp_day < DATE(?)",
                (cutoff_timestamp,) if table == 'hourly_aggregations'
                else (cutoff_timestamp,)
            )
            count = cursor.fetchone()['count']
            counts[table] = count
            total_count += count
        
        if dry_run:
            logger.info(f"[DRY RUN] Would delete aggregated data: {counts}")
            return (0, total_count)
        
        if total_count == 0:
            logger.info("No aggregated data to prune")
            return (0, 0)
        
        # Delete in transaction
        try:
            for table in tables_to_prune:
                if table == 'hourly_aggregations':
                    cursor.execute(
                        f"DELETE FROM {table} WHERE timestamp_hour < ?",
                        (cutoff_timestamp,)
                    )
                else:
                    cursor.execute(
                        f"DELETE FROM {table} WHERE timestamp_day < DATE(?)",
                        (cutoff_timestamp,)
                    )
            
            self.conn.commit()
            logger.info(f"Deleted aggregated data: {counts}")
            return (total_count, total_count)
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to prune aggregated data: {e}")
            return (0, 0)
    
    def prune_audit_logs(self, days: int, dry_run: bool = False) -> Tuple[int, int]:
        """Prune audit logs older than specified days"""
        cursor = self.conn.cursor()
        
        cutoff_date = datetime.now() - timedelta(days=days)
        cutoff_timestamp = cutoff_date.isoformat()
        
        logger.info(f"Pruning audit logs older than {days} days (before {cutoff_timestamp})")
        
        # Count affected rows
        cursor.execute(
            "SELECT COUNT(*) as count FROM audit_log WHERE timestamp < ?",
            (cutoff_timestamp,)
        )
        count = cursor.fetchone()['count']
        
        if dry_run:
            logger.info(f"[DRY RUN] Would delete {count} audit log entries")
            return (0, count)
        
        if count == 0:
            logger.info("No audit logs to prune")
            return (0, 0)
        
        # Delete in transaction
        try:
            cursor.execute(
                "DELETE FROM audit_log WHERE timestamp < ?",
                (cutoff_timestamp,)
            )
            
            self.conn.commit()
            logger.info(f"Deleted {count} audit log entries")
            return (count, count)
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to prune audit logs: {e}")
            return (0, 0)
    
    def prune_system_health(self, days: int, dry_run: bool = False) -> Tuple[int, int]:
        """Prune system health metrics older than specified days"""
        cursor = self.conn.cursor()
        
        cutoff_date = datetime.now() - timedelta(days=days)
        cutoff_timestamp = cutoff_date.isoformat()
        
        logger.info(f"Pruning system health data older than {days} days (before {cutoff_timestamp})")
        
        # Count affected rows
        cursor.execute(
            "SELECT COUNT(*) as count FROM system_health WHERE timestamp < ?",
            (cutoff_timestamp,)
        )
        count = cursor.fetchone()['count']
        
        if dry_run:
            logger.info(f"[DRY RUN] Would delete {count} system health entries")
            return (0, count)
        
        if count == 0:
            logger.info("No system health data to prune")
            return (0, 0)
        
        # Delete in transaction
        try:
            cursor.execute(
                "DELETE FROM system_health WHERE timestamp < ?",
                (cutoff_timestamp,)
            )
            
            self.conn.commit()
            logger.info(f"Deleted {count} system health entries")
            return (count, count)
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to prune system health data: {e}")
            return (0, 0)
    
    def vacuum_database(self) -> bool:
        """Run VACUUM to reclaim disk space"""
        try:
            logger.info("Running VACUUM to reclaim disk space")
            cursor = self.conn.cursor()
            cursor.execute("VACUUM")
            self.conn.commit()
            logger.info("VACUUM completed successfully")
            return True
        except Exception as e:
            logger.error(f"VACUUM failed: {e}")
            return False
    
    def analyze_database_size(self) -> Dict[str, int]:
        """Analyze database size by table"""
        cursor = self.conn.cursor()
        
        table_sizes = {}
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = [row['name'] for row in cursor.fetchall()]
        
        for table in tables:
            try:
                cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
                count = cursor.fetchone()['count']
                table_sizes[table] = count
            except Exception as e:
                logger.warning(f"Failed to get count for table {table}: {e}")
                table_sizes[table] = -1
        
        return table_sizes
    
    def run_retention(self, dry_run: bool = False, vacuum: bool = True) -> Dict[str, int]:
        """Run complete retention process"""
        logger.info(f"Starting data retention process (dry_run={dry_run}, vacuum={vacuum})")
        
        self.connect()
        
        # Get retention configuration
        retention_config = self.get_retention_config()
        logger.info(f"Retention configuration: {retention_config}")
        
        # Analyze current database size
        table_sizes_before = self.analyze_database_size()
        logger.info(f"Database size before pruning: {table_sizes_before}")
        
        # Prune data
        total_deleted = 0
        results = {}
        
        # Prune raw events
        deleted, total = self.prune_raw_events(
            retention_config.get('retention.raw_events_days', 30),
            dry_run
        )
        results['raw_events'] = deleted
        total_deleted += deleted
        
        # Prune aggregated data
        deleted, total = self.prune_aggregated_data(
            retention_config.get('retention.aggregated_data_days', 365),
            dry_run
        )
        results['aggregated_data'] = deleted
        total_deleted += deleted
        
        # Prune audit logs
        deleted, total = self.prune_audit_logs(
            retention_config.get('retention.audit_log_days', 90),
            dry_run
        )
        results['audit_logs'] = deleted
        total_deleted += deleted
        
        # Prune system health (use same retention as audit logs)
        deleted, total = self.prune_system_health(
            retention_config.get('retention.audit_log_days', 90),
            dry_run
        )
        results['system_health'] = deleted
        total_deleted += deleted
        
        # Run VACUUM if not dry run and vacuum is enabled
        if not dry_run and vacuum and total_deleted > 0:
            self.vacuum_database()
        
        # Analyze database size after pruning
        table_sizes_after = self.analyze_database_size()
        logger.info(f"Database size after pruning: {table_sizes_after}")
        
        self.close()
        
        results['total_deleted'] = total_deleted
        logger.info(f"Data retention process completed. Total deleted: {total_deleted}")
        
        return results


def main():
    """CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='AI Analytics Pipeline data retention and pruning')
    parser.add_argument('--db-path', default='analytics.db', help='Path to database file')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted without actually deleting')
    parser.add_argument('--no-vacuum', action='store_true', help='Skip VACUUM operation')
    
    args = parser.parse_args()
    
    # Create retention manager
    manager = DataRetentionManager(args.db_path)
    
    # Run retention process
    results = manager.run_retention(
        dry_run=args.dry_run,
        vacuum=not args.no_vacuum
    )
    
    # Print summary
    print("\nData Retention Summary:")
    print(f"  Raw events deleted: {results.get('raw_events', 0)}")
    print(f"  Aggregated data deleted: {results.get('aggregated_data', 0)}")
    print(f"  Audit logs deleted: {results.get('audit_logs', 0)}")
    print(f"  System health deleted: {results.get('system_health', 0)}")
    print(f"  Total deleted: {results.get('total_deleted', 0)}")
    
    if args.dry_run:
        print("\nDRY RUN MODE - No data was actually deleted")
    
    sys.exit(0)


if __name__ == '__main__':
    main()
