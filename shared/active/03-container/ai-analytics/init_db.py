#!/usr/bin/env python3
"""
Database Initialization Script for AI Analytics Pipeline
Initializes the database with schema and optional seed data
"""

import sqlite3
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime
from migrate import MigrationManager


def create_database(db_path: str, migrations_dir: str) -> bool:
    """Create and initialize database with migrations"""
    try:
        print(f"Creating database at: {db_path}")
        
        # Ensure parent directory exists
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        
        # Run migrations
        manager = MigrationManager(db_path, migrations_dir)
        success = manager.migrate()
        
        if success:
            print(f"\n✓ Database initialized successfully at: {db_path}")
            return True
        else:
            print(f"\n✗ Database initialization failed")
            return False
            
    except Exception as e:
        print(f"Error creating database: {e}")
        return False


def seed_database(db_path: str) -> bool:
    """Seed database with initial data"""
    try:
        print(f"Seeding database at: {db_path}")
        
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Seed subagent types
        subagent_types = [
            ('claude_code', 'Claude Code AI assistant'),
            ('codex', 'OpenAI Codex'),
            ('pi', 'Pi AI assistant'),
            ('devin', 'Devin AI assistant'),
            ('custom', 'Custom subagent')
        ]
        
        cursor.executemany("""
            INSERT OR IGNORE INTO subagent_types (type_name, description)
            VALUES (?, ?)
        """, subagent_types)
        
        # Seed tool types
        tool_types = [
            ('file_read', 'file', 'Read file contents'),
            ('file_write', 'file', 'Write to file'),
            ('web_search', 'web', 'Search the web'),
            ('web_fetch', 'web', 'Fetch web page'),
            ('database_query', 'database', 'Query database'),
            ('api_call', 'api', 'Make API call'),
            ('code_execution', 'code', 'Execute code'),
            ('shell_command', 'shell', 'Execute shell command'),
            ('custom', 'custom', 'Custom tool')
        ]
        
        cursor.executemany("""
            INSERT OR IGNORE INTO tool_types (type_name, category, description)
            VALUES (?, ?, ?)
        """, tool_types)
        
        # Seed basic configuration
        config_values = [
            ('retention_days', '90', 'number', 'Default data retention period in days'),
            ('cache_enabled', 'true', 'boolean', 'Enable caching'),
            ('analytics_enabled', 'true', 'boolean', 'Enable analytics collection'),
            ('max_request_size_mb', '10', 'number', 'Maximum request size in MB'),
            ('log_level', 'INFO', 'string', 'Default logging level')
        ]
        
        cursor.executemany("""
            INSERT OR IGNORE INTO configuration (config_key, config_value, config_type, description)
            VALUES (?, ?, ?, ?)
        """, config_values)
        
        conn.commit()
        conn.close()
        
        print("✓ Database seeded successfully")
        return True
        
    except Exception as e:
        print(f"Error seeding database: {e}")
        return False


def verify_database(db_path: str) -> bool:
    """Verify database integrity and schema"""
    try:
        print(f"Verifying database at: {db_path}")
        
        if not os.path.exists(db_path):
            print(f"✗ Database file does not exist: {db_path}")
            return False
        
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if schema_migrations table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='schema_migrations'
        """)
        
        if not cursor.fetchone():
            print("✗ Schema migrations table not found - database not initialized")
            return False
        
        # Get applied migrations
        cursor.execute("SELECT version, name, applied_at FROM schema_migrations ORDER BY version")
        migrations = cursor.fetchall()
        
        print(f"\n✓ Database is valid")
        print(f"\nApplied migrations ({len(migrations)}):")
        for version, name, applied_at in migrations:
            print(f"  - {version}: {name} (applied: {applied_at})")
        
        # Check table count
        cursor.execute("SELECT count(*) FROM sqlite_master WHERE type='table'")
        table_count = cursor.fetchone()[0]
        print(f"\nTotal tables: {table_count}")
        
        # Check index count
        cursor.execute("SELECT count(*) FROM sqlite_master WHERE type='index'")
        index_count = cursor.fetchone()[0]
        print(f"Total indexes: {index_count}")
        
        # Check view count
        cursor.execute("SELECT count(*) FROM sqlite_master WHERE type='view'")
        view_count = cursor.fetchone()[0]
        print(f"Total views: {view_count}")
        
        conn.close()
        
        print("\n✓ Database verification passed")
        return True
        
    except Exception as e:
        print(f"Error verifying database: {e}")
        return False


def reset_database(db_path: str, migrations_dir: str) -> bool:
    """Reset database by deleting and recreating"""
    try:
        print(f"Resetting database at: {db_path}")
        
        if os.path.exists(db_path):
            # Create backup
            backup_path = f"{db_path}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            os.rename(db_path, backup_path)
            print(f"Database backed up to: {backup_path}")
        
        # Create new database
        return create_database(db_path, migrations_dir)
        
    except Exception as e:
        print(f"Error resetting database: {e}")
        return False


def main():
    """Main entry point"""
    import argparse
    
    # Default paths
    script_dir = Path(__file__).parent
    default_db = str(script_dir / "analytics.db")
    default_migrations = str(script_dir / "migrations")
    
    parser = argparse.ArgumentParser(description="Database Initialization Script")
    parser.add_argument("--db", default=default_db, help="Database file path")
    parser.add_argument("--migrations", default=default_migrations, help="Migrations directory")
    parser.add_argument("command", choices=["init", "seed", "verify", "reset"], 
                       help="Command to execute")
    
    args = parser.parse_args()
    
    if args.command == "init":
        success = create_database(args.db, args.migrations)
        sys.exit(0 if success else 1)
    elif args.command == "seed":
        success = seed_database(args.db)
        sys.exit(0 if success else 1)
    elif args.command == "verify":
        success = verify_database(args.db)
        sys.exit(0 if success else 1)
    elif args.command == "reset":
        success = reset_database(args.db, args.migrations)
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
