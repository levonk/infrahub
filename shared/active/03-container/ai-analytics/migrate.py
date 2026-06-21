#!/usr/bin/env python3
"""
Database Migration System for AI Analytics Pipeline
Handles schema migrations with rollback support
"""

import sqlite3
import os
import sys
import hashlib
from pathlib import Path
from typing import List, Optional, Dict
from datetime import datetime


class Migration:
    """Represents a single database migration"""
    
    def __init__(self, version: int, filepath: Path):
        self.version = version
        self.filepath = filepath
        self.name = filepath.stem
        self.checksum = self._calculate_checksum()
        self.description = self._extract_description()
    
    def _calculate_checksum(self) -> str:
        """Calculate MD5 checksum of migration file"""
        with open(self.filepath, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    
    def _extract_description(self) -> str:
        """Extract description from migration file comments"""
        try:
            with open(self.filepath, 'r') as f:
                for line in f:
                    if line.strip().startswith('--'):
                        desc = line.strip().replace('--', '').strip()
                        if desc and not desc.lower().startswith('migration'):
                            return desc[:500]  # Limit description length
        except Exception:
            pass
        return f"Migration {self.version}"
    
    def read_content(self) -> str:
        """Read migration SQL content"""
        with open(self.filepath, 'r') as f:
            return f.read()


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
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
    
    def _ensure_migrations_table(self):
        """Ensure schema_migrations table exists"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='schema_migrations'
        """)
        
        if not cursor.fetchone():
            # For fresh databases, we need to create the table first
            # This is done manually here, then migration 0000 will record itself
            cursor.execute("""
                CREATE TABLE schema_migrations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    version INTEGER NOT NULL UNIQUE,
                    name TEXT NOT NULL,
                    applied_at TEXT NOT NULL DEFAULT (datetime('now')),
                    checksum TEXT,
                    description TEXT
                )
            """)
            self.conn.commit()
            print("Created schema_migrations table")
    
    def get_applied_migrations(self) -> Dict[int, sqlite3.Row]:
        """Get all applied migrations from database"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM schema_migrations ORDER BY version")
        return {int(row['version']): row for row in cursor.fetchall()}
    
    def get_pending_migrations(self) -> List[Migration]:
        """Get all pending migrations"""
        applied = self.get_applied_migrations()
        all_migrations = self._discover_migrations()
        
        pending = []
        for migration in all_migrations:
            if migration.version not in applied:
                pending.append(migration)
        
        return sorted(pending, key=lambda m: m.version)
    
    def _discover_migrations(self) -> List[Migration]:
        """Discover all migration files"""
        migrations = []
        
        if not self.migrations_dir.exists():
            return migrations
        
        for filepath in sorted(self.migrations_dir.glob("*.sql")):
            try:
                # Extract version number from filename (e.g., 0001_initial_schema.sql)
                version_str = filepath.name.split('_')[0]
                version = int(version_str)
                migrations.append(Migration(version, filepath))
            except (ValueError, IndexError):
                print(f"Warning: Skipping invalid migration file: {filepath.name}")
        
        return sorted(migrations, key=lambda m: m.version)
    
    def apply_migration(self, migration: Migration) -> bool:
        """Apply a single migration"""
        cursor = self.conn.cursor()
        
        try:
            # Read and execute migration SQL
            content = migration.read_content()
            
            # Check if this is a no-op migration (like 0000)
            is_noop = '-- No SQL needed' in content or content.strip() == ''
            
            if not is_noop:
                # Split by semicolons and execute each statement
                # (simple approach - for production, consider using a proper SQL parser)
                statements = [stmt.strip() for stmt in content.split(';') if stmt.strip()]
                
                for statement in statements:
                    if statement:
                        cursor.execute(statement)
            
            # Record migration
            cursor.execute("""
                INSERT INTO schema_migrations (version, name, checksum, description, applied_at)
                VALUES (?, ?, ?, ?, ?)
            """, (migration.version, migration.name, migration.checksum, 
                  migration.description, datetime.now().isoformat()))
            
            self.conn.commit()
            print(f"✓ Applied migration {migration.version}: {migration.name}")
            return True
            
        except Exception as e:
            self.conn.rollback()
            print(f"✗ Failed to apply migration {migration.version}: {e}")
            return False
    
    def migrate(self) -> bool:
        """Apply all pending migrations"""
        try:
            self.connect()
            self._ensure_migrations_table()
            
            pending = self.get_pending_migrations()
            
            if not pending:
                print("No pending migrations to apply.")
                return True
            
            print(f"Found {len(pending)} pending migration(s):")
            for migration in pending:
                print(f"  - {migration.version}: {migration.name}")
            
            print("\nApplying migrations...")
            for migration in pending:
                if not self.apply_migration(migration):
                    return False
            
            print("\nAll migrations applied successfully!")
            return True
            
        except Exception as e:
            print(f"Migration failed: {e}")
            return False
        finally:
            self.close()
    
    def rollback(self, target_version: Optional[int] = None) -> bool:
        """
        Rollback to a specific version
        Note: This is a destructive operation - use with caution
        """
        try:
            self.connect()
            self._ensure_migrations_table()
            
            applied = self.get_applied_migrations()
            
            if not applied:
                print("No migrations to rollback.")
                return True
            
            # Determine target version
            if target_version is None:
                # Rollback one version
                target_version = max(applied.keys()) - 1
                if target_version < 0:
                    print("Cannot rollback - no migrations applied.")
                    return False
            
            if target_version not in applied and target_version != 0:
                print(f"Version {target_version} is not in migration history.")
                return False
            
            # Get versions to rollback
            to_rollback = [v for v in applied.keys() if v > target_version]
            
            if not to_rollback:
                print(f"Already at version {target_version}.")
                return True
            
            print(f"Rolling back {len(to_rollback)} migration(s):")
            for version in sorted(to_rollback, reverse=True):
                print(f"  - {version}: {applied[version]['name']}")
            
            # For SQLite, we need to drop and recreate the database
            # This is a simple approach - production systems should implement proper rollback scripts
            print("\nWarning: SQLite rollback requires database recreation.")
            print("This will delete all data. Backup recommended before proceeding.")
            
            response = input("Proceed with rollback? (yes/no): ")
            if response.lower() != 'yes':
                print("Rollback cancelled.")
                return False
            
            # Close connection and recreate database
            self.close()
            
            # Backup existing database
            backup_path = f"{self.db_path}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            os.rename(self.db_path, backup_path)
            print(f"Database backed up to: {backup_path}")
            
            # Create new database and apply migrations up to target version
            self.connect()
            self._ensure_migrations_table()
            
            # Apply migrations up to target version
            all_migrations = self._discover_migrations()
            for migration in all_migrations:
                if migration.version <= target_version:
                    if not self.apply_migration(migration):
                        print(f"Failed to apply migration {migration.version} during rollback.")
                        return False
            
            print(f"\nRollback to version {target_version} completed successfully!")
            return True
            
        except Exception as e:
            print(f"Rollback failed: {e}")
            return False
        finally:
            self.close()
    
    def status(self):
        """Show migration status"""
        try:
            self.connect()
            self._ensure_migrations_table()
            
            applied = self.get_applied_migrations()
            pending = self.get_pending_migrations()
            
            print("\nMigration Status:")
            print("=" * 60)
            
            if applied:
                print("\nApplied Migrations:")
                for version in sorted(applied.keys()):
                    row = applied[version]
                    print(f"  ✓ {version}: {row['name']} (applied: {row['applied_at']})")
            else:
                print("\nNo migrations applied yet.")
            
            if pending:
                print("\nPending Migrations:")
                for migration in pending:
                    print(f"  ○ {migration.version}: {migration.name}")
            else:
                print("\nNo pending migrations.")
            
            print("\n" + "=" * 60)
            
        except Exception as e:
            print(f"Failed to get migration status: {e}")
        finally:
            self.close()


def main():
    """Main entry point"""
    import argparse
    
    # Default paths
    default_db = os.path.join(os.path.dirname(__file__), "analytics.db")
    default_migrations = os.path.join(os.path.dirname(__file__), "migrations")
    
    parser = argparse.ArgumentParser(description="Database Migration System")
    parser.add_argument("--db", default=default_db, help="Database file path")
    parser.add_argument("--migrations", default=default_migrations, help="Migrations directory")
    parser.add_argument("command", choices=["migrate", "rollback", "status"], help="Command to execute")
    parser.add_argument("--to", type=int, help="Target version for rollback")
    
    args = parser.parse_args()
    
    manager = MigrationManager(args.db, args.migrations)
    
    if args.command == "migrate":
        success = manager.migrate()
        sys.exit(0 if success else 1)
    elif args.command == "rollback":
        success = manager.rollback(args.to)
        sys.exit(0 if success else 1)
    elif args.command == "status":
        manager.status()


if __name__ == "__main__":
    main()
