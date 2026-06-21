#!/usr/bin/env python3
"""
Schema Validation Tests for AI Analytics Pipeline
Tests database schema creation, migrations, and basic operations
"""

import sqlite3
import os
import sys
import tempfile
from pathlib import Path
from migrate import MigrationManager
from init_db import create_database, seed_database, verify_database


def test_schema_creation():
    """Test that schema can be created successfully"""
    print("Testing schema creation...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database
        success = create_database(db_path, migrations_dir)
        
        if not success:
            print("✗ Schema creation failed")
            return False
        
        # Verify database exists
        if not os.path.exists(db_path):
            print("✗ Database file not created")
            return False
        
        print("✓ Schema creation successful")
        return True


def test_migration_system():
    """Test migration system functionality"""
    print("Testing migration system...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database using migration manager
        manager = MigrationManager(db_path, migrations_dir)
        success = manager.migrate()
        
        if not success:
            print("✗ Migration failed")
            return False
        
        # Check that migrations were applied
        manager.connect()
        applied = manager.get_applied_migrations()
        manager.close()
        
        if len(applied) < 2:  # Should have at least migration 0 and 1
            print(f"✗ Expected at least 2 migrations, got {len(applied)}")
            return False
        
        print(f"✓ Migration system working ({len(applied)} migrations applied)")
        return True


def test_table_structure():
    """Test that all required tables exist"""
    print("Testing table structure...")
    
    required_tables = [
        'users', 'machines', 'client_keys', 'request_events',
        'subagent_types', 'subagent_events', 'tool_types', 'tool_events',
        'tool_heatmaps', 'file_events', 'file_heatmaps', 'sessions',
        'session_turns', 'cache_events', 'cache_statistics', 'skills',
        'skill_events', 'daily_metrics', 'time_series_data', 'configuration',
        'provider_config', 'model_config', 'schema_migrations'
    ]
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database
        create_database(db_path, migrations_dir)
        
        # Check tables
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        existing_tables = {row[0] for row in cursor.fetchall()}
        
        conn.close()
        
        missing_tables = set(required_tables) - existing_tables
        if missing_tables:
            print(f"✗ Missing tables: {missing_tables}")
            return False
        
        print(f"✓ All {len(required_tables)} required tables exist")
        return True


def test_foreign_keys():
    """Test that foreign key constraints are properly defined"""
    print("Testing foreign key constraints...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database
        create_database(db_path, migrations_dir)
        
        # Test foreign key by inserting invalid data
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Enable foreign keys
        cursor.execute("PRAGMA foreign_keys = ON")
        
        # Try to insert request event with non-existent user
        try:
            cursor.execute("""
                INSERT INTO request_events 
                (event_id, timestamp, user_id, ai_client, provider, model, input_type)
                VALUES ('test_event', '2025-01-20', 99999, 'claude_code', 'anthropic', 'claude-3-opus', 'text')
            """)
            conn.commit()
            print("✗ Foreign key constraint not enforced")
            conn.close()
            return False
        except sqlite3.IntegrityError:
            # Expected - foreign key constraint should prevent this
            conn.rollback()
        
        conn.close()
        print("✓ Foreign key constraints working")
        return True


def test_indexes():
    """Test that performance indexes exist"""
    print("Testing performance indexes...")
    
    required_indexes = [
        'idx_request_events_user_id',
        'idx_request_events_timestamp',
        'idx_request_events_provider',
        'idx_subagent_events_request_event_id',
        'idx_tool_events_request_event_id',
        'idx_time_series_data_timestamp_granularity'
    ]
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database
        create_database(db_path, migrations_dir)
        
        # Check indexes
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='index'")
        existing_indexes = {row[0] for row in cursor.fetchall()}
        
        conn.close()
        
        missing_indexes = set(required_indexes) - existing_indexes
        if missing_indexes:
            print(f"✗ Missing indexes: {missing_indexes}")
            return False
        
        print(f"✓ All {len(required_indexes)} required indexes exist")
        return True


def test_views():
    """Test that analytical views exist"""
    print("Testing analytical views...")
    
    required_views = [
        'request_summary',
        'daily_cost_summary',
        'user_activity_summary',
        'tool_usage_summary',
        'session_summary',
        'cache_performance_summary'
    ]
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create database
        create_database(db_path, migrations_dir)
        
        # Check views
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='view'")
        existing_views = {row[0] for row in cursor.fetchall()}
        
        conn.close()
        
        missing_views = set(required_views) - existing_views
        if missing_views:
            print(f"✗ Missing views: {missing_views}")
            return False
        
        print(f"✓ All {len(required_views)} required views exist")
        return True


def test_basic_crud():
    """Test basic CRUD operations"""
    print("Testing basic CRUD operations...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_analytics.db")
        migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")
        
        # Create and seed database
        create_database(db_path, migrations_dir)
        seed_database(db_path)
        
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Test INSERT
        cursor.execute("""
            INSERT INTO users (user_id, username, email)
            VALUES ('test_user', 'Test User', 'test@example.com')
        """)
        conn.commit()
        
        # Test SELECT
        cursor.execute("SELECT * FROM users WHERE user_id = 'test_user'")
        user = cursor.fetchone()
        
        if not user or user[2] != 'Test User':
            print("✗ INSERT or SELECT failed")
            conn.close()
            return False
        
        # Test UPDATE
        cursor.execute("""
            UPDATE users SET username = 'Updated User' WHERE user_id = 'test_user'
        """)
        conn.commit()
        
        cursor.execute("SELECT username FROM users WHERE user_id = 'test_user'")
        updated_user = cursor.fetchone()
        
        if not updated_user or updated_user[0] != 'Updated User':
            print("✗ UPDATE failed")
            conn.close()
            return False
        
        # Test DELETE
        cursor.execute("DELETE FROM users WHERE user_id = 'test_user'")
        conn.commit()
        
        cursor.execute("SELECT COUNT(*) FROM users WHERE user_id = 'test_user'")
        count = cursor.fetchone()[0]
        
        if count != 0:
            print("✗ DELETE failed")
            conn.close()
            return False
        
        conn.close()
        print("✓ Basic CRUD operations working")
        return True


def run_all_tests():
    """Run all schema validation tests"""
    print("=" * 60)
    print("AI Analytics Pipeline - Schema Validation Tests")
    print("=" * 60)
    print()
    
    tests = [
        test_schema_creation,
        test_migration_system,
        test_table_structure,
        test_foreign_keys,
        test_indexes,
        test_views,
        test_basic_crud
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"✗ Test failed with exception: {e}")
            failed += 1
        print()
    
    print("=" * 60)
    print(f"Test Results: {passed} passed, {failed} failed")
    print("=" * 60)
    
    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
