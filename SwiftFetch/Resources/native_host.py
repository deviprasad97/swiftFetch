#!/usr/bin/env python3
"""
SwiftFetch Native Messaging Host
Handles communication between Chrome extension and SwiftFetch app
"""

import sys
import json
import struct
import logging
import subprocess
import os

# Set up logging for debugging
logging.basicConfig(
    filename='/tmp/swiftfetch_native.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def read_message():
    """Read a message from Chrome using Native Messaging protocol"""
    # Read the message length (first 4 bytes)
    raw_length = sys.stdin.buffer.read(4)
    
    if not raw_length:
        return None
    
    # Unpack message length
    message_length = struct.unpack('I', raw_length)[0]
    
    # Read the message
    message = sys.stdin.buffer.read(message_length).decode('utf-8')
    
    return json.loads(message)

def write_message(message):
    """Write a message to Chrome using Native Messaging protocol"""
    encoded = json.dumps(message).encode('utf-8')
    
    # Write message length
    sys.stdout.buffer.write(struct.pack('I', len(encoded)))
    
    # Write the message
    sys.stdout.buffer.write(encoded)
    sys.stdout.flush()

def handle_download(url, filename=None):
    """Send download to SwiftFetch app"""
    try:
        # Find SwiftFetch app
        app_paths = [
            "/Applications/SwiftFetch.app",
            "/Users/devitripathy/Library/Developer/Xcode/DerivedData/SwiftFetch-hkguncbcnfxahpcsjswpmkdlbqjt/Build/Products/Debug/SwiftFetch.app"
        ]
        
        app_path = None
        for path in app_paths:
            if os.path.exists(path):
                app_path = path
                break
        
        if not app_path:
            return False
        
        # Use open command with URL
        subprocess.run(['open', '-a', app_path, url], check=True)
        
        return True
    except Exception as e:
        logging.error(f"Error handling download: {e}")
        return False

def main():
    logging.info("Native host started")
    
    while True:
        try:
            message = read_message()
            
            if not message:
                break
            
            logging.info(f"Received message: {message}")
            
            # Handle different message types
            msg_type = message.get('type', '')
            
            if msg_type == 'ping':
                # Respond to ping
                response = {
                    'type': 'pong',
                    'status': 'connected',
                    'version': '1.0.0'
                }
                write_message(response)
                
            elif msg_type == 'download':
                # Handle download request
                url = message.get('url', '')
                filename = message.get('filename', '')
                
                success = handle_download(url, filename)
                
                response = {
                    'type': 'download_response',
                    'success': success,
                    'url': url
                }
                write_message(response)
                
            elif msg_type == 'status':
                # Return status
                response = {
                    'type': 'status_response',
                    'connected': True,
                    'app_running': True
                }
                write_message(response)
                
            else:
                # Unknown message type
                response = {
                    'type': 'error',
                    'message': f'Unknown message type: {msg_type}'
                }
                write_message(response)
                
            logging.info(f"Sent response: {response}")
            
        except Exception as e:
            logging.error(f"Error processing message: {e}")
            error_response = {
                'type': 'error',
                'message': str(e)
            }
            try:
                write_message(error_response)
            except:
                pass
    
    logging.info("Native host exiting")

if __name__ == '__main__':
    main()