#!/usr/bin/env python3
"""
AI Analytics Pipeline - Database Initialization Script
Initializes the database with schema and default data
"""

import sqlite3
import os
import sys
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DatabaseInitializer:
    """Handles database initialization"""
    
    def __init__(self, db_path: str, schema_path: str, migrations_dir: str):
        self.db_path = db_path
        self.schema_path = Path(schema_path)
        self.migrations_dir = Path(migrations_dir)
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
    
    def initialize_schema(self):
        """Initialize database schema from schema.sql file"""
        if not self.schema_path.exists():
            logger.error(f"Schema file not found: {self.schema_path}")
            return False
        
        try:
            logger.info(f"Loading schema from: {self.schema_path}")
            with open(self.schema_path, 'r') as f:
                schema_sql = f.read()
            
            logger.info("Applying schema to database")
            cursor = self.conn.cursor()
            cursor.executescript(schema_sql)
            self.conn.commit()
            
            logger.info("Schema initialized successfully")
            return True
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to initialize schema: {e}")
            return False
    
    def run_migrations(self):
        """Run database migrations"""
        try:
            # Import migration manager
            sys.path.insert(0, str(self.migrations_dir))
            from migrate import MigrationManager
            
            logger.info("Running database migrations")
            manager = MigrationManager(self.db_path, str(self.migrations_dir))
            success = manager.migrate()
            
            if success:
                logger.info("Migrations completed successfully")
            else:
                logger.error("Migrations failed")
            
            return success
            
        except ImportError as e:
            logger.error(f"Failed to import migration manager: {e}")
            return False
        except Exception as e:
            logger.error(f"Migration error: {e}")
            return False
    
    def initialize_default_data(self):
        """Initialize default configuration data"""
        try:
            logger.info("Initializing default configuration data")
            cursor = self.conn.cursor()
            
            # Default configuration values
            default_configs = [
                ('retention.raw_events_days', '30', 'integer', 'Retention period for raw events in days'),
                ('retention.aggregated_data_days', '365', 'integer', 'Retention period for aggregated data in days'),
                ('retention.audit_log_days', '90', 'integer', 'Retention period for audit logs in days'),
                ('analytics.batch_size', '1000', 'integer', 'Batch size for analytics processing'),
                ('analytics.flush_interval', '60', 'integer', 'Flush interval in seconds'),
                ('analytics.max_retries', '3', 'integer', 'Maximum retry attempts for failed operations'),
                ('processor.workers', '4', 'integer', 'Number of background processor workers'),
                ('api.rate_limit_enabled', 'true', 'boolean', 'Enable API rate limiting'),
                ('api.rate_limit_requests_per_minute', '100', 'integer', 'API rate limit requests per minute'),
                ('monitoring.metrics_enabled', 'true', 'boolean', 'Enable metrics collection'),
                ('monitoring.health_check_enabled', 'true', 'boolean', 'Enable health check endpoint'),
                ('security.encryption_enabled', 'true', 'boolean', 'Enable data encryption'),
                ('security.encryption_algorithm', 'AES-256-GCM', 'string', 'Encryption algorithm to use'),
            ]
            
            for config_key, config_value, config_type, description in default_configs:
                cursor.execute("""
                    INSERT OR IGNORE INTO configuration (config_key, config_value, config_type, description)
                    VALUES (?, ?, ?, ?)
                """, (config_key, config_value, config_type, description))
            
            self.conn.commit()
            logger.info(f"Initialized {len(default_configs)} default configuration values")
            return True
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to initialize default data: {e}")
            return False
    
    def verify_schema(self):
        """Verify that the schema was created correctly"""
        try:
            logger.info("Verifying database schema")
            cursor = self.conn.cursor()
            
            # Get list of tables
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            tables = [row['name'] for row in cursor.fetchall()]
            
            expected_tables = [
                'users', 'machines', 'client_keys',
                'request_events', 'response_events',
                'subagents', 'subagent_requests',
                'tools', 'tool_invocations',
                'files', 'file_accesses',
                'sessions', 'session_turns',
                'cache_entries', 'cache_events',
                'skills', 'skill_invocations',
                'providers', 'models', 'model_usage_history',
                'hourly_aggregations', 'daily_aggregations',
                'configuration', 'audit_log', 'system_health',
                'schema_migrations'
            ]
            
            missing_tables = set(expected_tables) - set(tables)
            if missing_tables:
                logger.error(f"Missing tables: {missing_tables}")
                return False
            
            # Check indexes
            cursor.execute("SELECT name FROM sqlite_master WHERE type='index' ORDER BY name")
            indexes = [row['name'] for row in cursor.fetchall()]
            
            if len(indexes) < 20:  # We should have many indexes
                logger.warning(f"Expected more indexes, found: {len(indexes)}")
            
            # Check views
            cursor.execute("SELECT name FROM sqlite_master WHERE type='view' ORDER BY name")
            views = [row['name'] for row in cursor.fetchall()]
            
            expected_views = [
                'v_request_summary', 'v_daily_cost_summary', 
                'v_tool_usage_summary', 'v_file_access_summary',
                'v_cache_performance_summary'
            ]
            
            missing_views = set(expected_views) - set(views)
            if missing_views:
                logger.error(f"Missing views: {missing_views}")
                return False
            
            logger.info(f"Schema verification passed: {len(tables)} tables, {len(indexes)} indexes, {len(views)} views")
            return True
            
        except Exception as e:
            logger.error(f"Schema verification failed: {e}")
            return False
    
    def initialize(self):
        """Complete database initialization process"""
        logger.info("Starting database initialization")
        
        self.connect()
        
        # Step 1: Initialize schema
        if not self.initialize_schema():
            self.close()
            return False
        
        # Step 2: Run migrations
        if not self.run_migrations():
            self.close()
            return False
        
        # Step 3: Initialize default data
        if not self.initialize_default_data():
            self.close()
            return False
        
        # Step 4: Verify schema
        if not self.verify_schema():
            self.close()
            return False
        
        self.close()
        logger.info("Database initialization completed successfully")
        return True


def main():
    """CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Initialize AI Analytics Pipeline database')
    parser.add_argument('--db-path', default='analytics.db', help='Path to database file')
    parser.add_argument('--schema-path', default='schema.sql', help='Path to schema.sql file')
    parser.add_argument('--migrations-dir', default='migrations', help='Path to migrations directory')
    
    args = parser.parse_args()
    
    # Create initializer
    initializer = DatabaseInitializer(
        args.db_path,
        args.schema_path,
        args.migrations_dir
    )
    
    # Run initialization
    success = initializer.initialize()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
