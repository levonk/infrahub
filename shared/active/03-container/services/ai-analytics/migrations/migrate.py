#!/usr/bin/env python3
"""
AI Analytics Pipeline - Database Migration System
Handles schema migrations with rollback support and version tracking
"""

import sqlite3
import os
import hashlib
from pathlib import Path
from typing import Optional, List, Dict
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Migration:
    """Represents a single database migration"""
    
    def __init__(self, version: str, name: str, up_sql: str, down_sql: Optional[str] = None):
        self.version = version
        self.name = name
        self.up_sql = up_sql
        self.down_sql = down_sql
        self.checksum = self._calculate_checksum(up_sql)
    
    def _calculate_checksum(self, sql: str) -> str:
        """Calculate SHA256 checksum of SQL"""
        return hashlib.sha256(sql.encode('utf-8')).hexdigest()


class MigrationManager:
    """Manages database migrations"""
    
    def __init__(self, db_path: str, migrations_dir: str):
        self.db_path = db_path
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
    
    def ensure_schema_migrations_table(self):
        """Ensure the schema_migrations table exists"""
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                rollback_sql TEXT,
                checksum TEXT
            )
        """)
        self.conn.commit()
        logger.info("Ensured schema_migrations table exists")
    
    def load_migrations(self) -> List[Migration]:
        """Load all migration files from the migrations directory"""
        migrations = []
        
        # Sort migration files by version
        migration_files = sorted(self.migrations_dir.glob("*.sql"))
        
        for migration_file in migration_files:
            # Extract version and name from filename
            # Format: 001_initial_schema.sql
            parts = migration_file.stem.split('_', 1)
            if len(parts) >= 2:
                version = parts[0]
                name = parts[1]
                
                # Read migration SQL
                with open(migration_file, 'r') as f:
                    sql_content = f.read()
                
                # Split into up and down migrations if both exist
                # For now, we'll treat the entire file as the up migration
                migration = Migration(version, name, sql_content)
                migrations.append(migration)
                logger.info(f"Loaded migration: {version} - {name}")
        
        return migrations
    
    def get_applied_migrations(self) -> Dict[str, Dict]:
        """Get list of applied migrations from database"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT version, name, applied_at, checksum FROM schema_migrations ORDER BY version")
        applied = {}
        for row in cursor.fetchall():
            applied[row['version']] = {
                'name': row['name'],
                'applied_at': row['applied_at'],
                'checksum': row['checksum']
            }
        return applied
    
    def apply_migration(self, migration: Migration) -> bool:
        """Apply a single migration"""
        cursor = self.conn.cursor()
        
        try:
            logger.info(f"Applying migration: {migration.version} - {migration.name}")
            
            # Execute migration SQL
            cursor.executescript(migration.up_sql)
            
            # Record migration
            cursor.execute("""
                INSERT INTO schema_migrations (version, name, checksum)
                VALUES (?, ?, ?)
            """, (migration.version, migration.name, migration.checksum))
            
            self.conn.commit()
            logger.info(f"Successfully applied migration: {migration.version}")
            return True
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to apply migration {migration.version}: {e}")
            return False
    
    def rollback_migration(self, version: str) -> bool:
        """Rollback a specific migration"""
        cursor = self.conn.cursor()
        
        try:
            # Get migration details
            cursor.execute(
                "SELECT rollback_sql, checksum FROM schema_migrations WHERE version = ?",
                (version,)
            )
            row = cursor.fetchone()
            
            if not row:
                logger.error(f"Migration {version} not found in applied migrations")
                return False
            
            if not row['rollback_sql']:
                logger.error(f"No rollback SQL available for migration {version}")
                return False
            
            logger.info(f"Rolling back migration: {version}")
            
            # Execute rollback SQL
            cursor.executescript(row['rollback_sql'])
            
            # Remove migration record
            cursor.execute("DELETE FROM schema_migrations WHERE version = ?", (version,))
            
            self.conn.commit()
            logger.info(f"Successfully rolled back migration: {version}")
            return True
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Failed to rollback migration {version}: {e}")
            return False
    
    def migrate(self, target_version: Optional[str] = None) -> bool:
        """Run all pending migrations up to target version"""
        self.connect()
        self.ensure_schema_migrations_table()
        
        migrations = self.load_migrations()
        applied_migrations = self.get_applied_migrations()
        
        # Filter migrations that need to be applied
        pending_migrations = []
        for migration in migrations:
            if migration.version not in applied_migrations:
                pending_migrations.append(migration)
                if target_version and migration.version > target_version:
                    break
        
        if not pending_migrations:
            logger.info("No pending migrations to apply")
            self.close()
            return True
        
        logger.info(f"Found {len(pending_migrations)} pending migrations")
        
        # Apply migrations in order
        for migration in pending_migrations:
            if not self.apply_migration(migration):
                logger.error(f"Migration failed at version {migration.version}")
                self.close()
                return False
        
        logger.info(f"Successfully applied {len(pending_migrations)} migrations")
        self.close()
        return True
    
    def rollback(self, steps: int = 1) -> bool:
        """Rollback the last N migrations"""
        self.connect()
        
        # Get applied migrations in reverse order
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT ?",
            (steps,)
        )
        versions_to_rollback = [row['version'] for row in cursor.fetchall()]
        
        if not versions_to_rollback:
            logger.info("No migrations to rollback")
            self.close()
            return True
        
        logger.info(f"Rolling back {len(versions_to_rollback)} migrations")
        
        # Rollback in reverse order
        for version in reversed(versions_to_rollback):
            if not self.rollback_migration(version):
                logger.error(f"Rollback failed at version {version}")
                self.close()
                return False
        
        logger.info(f"Successfully rolled back {len(versions_to_rollback)} migrations")
        self.close()
        return True
    
    def status(self) -> Dict:
        """Show migration status"""
        self.connect()
        self.ensure_schema_migrations_table()
        
        migrations = self.load_migrations()
        applied_migrations = self.get_applied_migrations()
        
        status = {
            'total_migrations': len(migrations),
            'applied_migrations': len(applied_migrations),
            'pending_migrations': len(migrations) - len(applied_migrations),
            'migrations': []
        }
        
        for migration in migrations:
            migration_status = {
                'version': migration.version,
                'name': migration.name,
                'applied': migration.version in applied_migrations,
                'applied_at': applied_migrations.get(migration.version, {}).get('applied_at') if migration.version in applied_migrations else None,
                'checksum': migration.checksum
            }
            status['migrations'].append(migration_status)
        
        self.close()
        return status


def main():
    """CLI entry point"""
    import sys
    
    # Default database path
    db_path = os.environ.get('ANALYTICS_DB_PATH', 'analytics.db')
    migrations_dir = os.environ.get('ANALYTICS_MIGRATIONS_DIR', 'migrations')
    
    # Create migration manager
    manager = MigrationManager(db_path, migrations_dir)
    
    # Parse command
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    
    if command == 'migrate':
        target_version = sys.argv[2] if len(sys.argv) > 2 else None
        success = manager.migrate(target_version)
        sys.exit(0 if success else 1)
        
    elif command == 'rollback':
        steps = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        success = manager.rollback(steps)
        sys.exit(0 if success else 1)
        
    elif command == 'status':
        status = manager.status()
        print(f"Total migrations: {status['total_migrations']}")
        print(f"Applied migrations: {status['applied_migrations']}")
        print(f"Pending migrations: {status['pending_migrations']}")
        print("\nMigration details:")
        for migration in status['migrations']:
            status_str = "✓ Applied" if migration['applied'] else "○ Pending"
            print(f"  {status_str} {migration['version']} - {migration['name']}")
            if migration['applied']:
                print(f"    Applied at: {migration['applied_at']}")
        sys.exit(0)
        
    else:
        print(f"Unknown command: {command}")
        print("Available commands: migrate, rollback, status")
        sys.exit(1)


if __name__ == '__main__':
    main()
