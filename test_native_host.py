#!/usr/bin/env python3
"""Test the native messaging host"""

import struct
import json
import subprocess

def send_native_message(message):
    """Send a message using native messaging protocol"""
    encoded = json.dumps(message).encode('utf-8')
    
    # Prepare the message with length prefix
    length_bytes = struct.pack('I', len(encoded))
    full_message = length_bytes + encoded
    
    # Run the native host
    proc = subprocess.Popen(
        ['/Users/devitripathy/code/download_manager/SwiftFetch/SwiftFetch/Resources/native_host.py'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Send message and get response
    stdout, stderr = proc.communicate(input=full_message)
    
    # Parse response
    if len(stdout) >= 4:
        response_length = struct.unpack('I', stdout[:4])[0]
        response = stdout[4:4+response_length].decode('utf-8')
        return json.loads(response)
    
    return None

# Test ping
print("Testing ping...")
response = send_native_message({"type": "ping"})
print(f"Response: {response}")

# Test status
print("\nTesting status...")
response = send_native_message({"type": "status"})
print(f"Response: {response}")