#!/usr/bin/env python3
"""
Test script to verify stream persistence functionality
"""

import sys
import json
import tempfile
import getpass
from pathlib import Path

def get_config_directory():
    """Test the config directory logic"""
    import os
    
    # Try standard config directory first
    config_dir = Path.home() / ".config" / "rdx"
    
    try:
        # Create and test if we can write to standard location
        config_dir.mkdir(parents=True, exist_ok=True)
        test_file = config_dir / ".test"
        test_file.touch()
        test_file.unlink()
        return config_dir
    except (PermissionError, OSError) as e:
        print(f"Standard config dir failed: {e}")
        # If standard location fails, try creating in home directory
        fallback_dir = Path.home() / ".rdx"
        try:
            fallback_dir.mkdir(parents=True, exist_ok=True)
            return fallback_dir
        except (PermissionError, OSError) as e2:
            print(f"Fallback config dir failed: {e2}")
            # Last resort - use temp directory with user-specific name
            temp_dir = Path(tempfile.gettempdir()) / f"rdx-{getpass.getuser()}"
            temp_dir.mkdir(parents=True, exist_ok=True)
            return temp_dir

def test_stream_persistence():
    """Test saving and loading streams"""
    print("🧪 Testing Stream Persistence")
    print("=" * 50)
    
    # Get config directory
    config_dir = get_config_directory()
    print(f"📁 Config directory: {config_dir}")
    
    # Test stream data
    test_streams = [
        {
            'codec': 'MP3',
            'bitrate': '192 kbps',
            'mount': '/mp3-192',
            'station_name': 'Test Station',
            'genre': 'Rock',
            'description': 'Test stream'
        },
        {
            'codec': 'AAC+',
            'bitrate': '64 kbps', 
            'mount': '/aac-64',
            'station_name': 'Test AAC Station',
            'genre': 'Pop',
            'description': 'AAC test stream'
        }
    ]
    
    # Test saving streams
    try:
        streams_file = config_dir / "streams.json"
        with open(streams_file, 'w') as f:
            json.dump(test_streams, f, indent=2)
        print(f"✅ Successfully saved {len(test_streams)} streams to {streams_file}")
    except Exception as e:
        print(f"❌ Failed to save streams: {e}")
        return False
    
    # Test loading streams
    try:
        with open(streams_file, 'r') as f:
            loaded_streams = json.load(f)
        print(f"✅ Successfully loaded {len(loaded_streams)} streams")
        
        # Verify data integrity
        if loaded_streams == test_streams:
            print("✅ Stream data integrity verified")
        else:
            print("❌ Stream data integrity check failed")
            return False
            
    except Exception as e:
        print(f"❌ Failed to load streams: {e}")
        return False
    
    # Test config file creation
    try:
        liquidsoap_config = config_dir / "radio.liq"
        liquidsoap_config.write_text("# Test liquidsoap config\ntest_source = blank()")
        print(f"✅ Successfully created config file: {liquidsoap_config}")
    except Exception as e:
        print(f"❌ Failed to create config file: {e}")
        return False
    
    return True

if __name__ == "__main__":
    success = test_stream_persistence()
    if success:
        print("\n🎉 All persistence tests passed!")
    else:
        print("\n💥 Some tests failed!")
        sys.exit(1)