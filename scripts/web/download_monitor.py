#!/usr/bin/env python3
from flask import Flask, render_template, jsonify, request, redirect, url_for
from flask_socketio import SocketIO, emit
import os
import json
import time
from datetime import datetime
import subprocess
import threading
import queue
import psutil

app = Flask(__name__)
socketio = SocketIO(app)

# Configuration
STORAGE_ROOT = os.getenv('STORAGE_ROOT', '/storage')
BOOKS_DIR = f"{STORAGE_ROOT}/library/gutenberg"
PROGRESS_FILE = f"{STORAGE_ROOT}/library/download_progress.log"
FAILED_LOG = f"{STORAGE_ROOT}/library/failed_downloads.log"
METADATA_DIR = f"{STORAGE_ROOT}/library/.metadata"

# Global state
download_status = {
    'active': False,
    'total_books': 0,
    'downloaded': 0,
    'failed': 0,
    'current_speed': 0,
    'eta': None,
    'active_downloads': []
}

def monitor_downloads():
    """Background thread to monitor download progress"""
    while True:
        if download_status['active']:
            # Update statistics
            download_status['downloaded'] = sum(1 for _ in open(PROGRESS_FILE) if ':SUCCESS' in _)
            download_status['failed'] = sum(1 for _ in open(FAILED_LOG))
            
            # Monitor active downloads
            active_downloads = []
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                if 'wget' in proc.info['name']:
                    try:
                        cmd = proc.info['cmdline']
                        if cmd and any(BOOKS_DIR in arg for arg in cmd):
                            book_id = next(arg for arg in cmd if arg.endswith('.txt')).split('/')[-1].replace('.txt', '')
                            active_downloads.append({
                                'book_id': book_id,
                                'speed': get_download_speed(proc.pid),
                                'progress': get_download_progress(book_id)
                            })
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue
            
            download_status['active_downloads'] = active_downloads
            
            # Emit update via WebSocket
            socketio.emit('status_update', download_status)
        time.sleep(1)

def get_download_speed(pid):
    """Get current download speed for a process"""
    try:
        proc = psutil.Process(pid)
        io_counters = proc.io_counters()
        time.sleep(1)
        io_counters_new = proc.io_counters()
        return (io_counters_new.read_bytes - io_counters.read_bytes) / 1024  # KB/s
    except:
        return 0

def get_download_progress(book_id):
    """Get download progress for a book"""
    part_file = f"{BOOKS_DIR}/{book_id}.txt.part"
    if os.path.exists(part_file):
        return os.path.getsize(part_file)
    return 0

@app.route('/')
def index():
    return render_template('index.html', status=download_status)

@app.route('/api/status')
def get_status():
    return jsonify(download_status)

@app.route('/api/start', methods=['POST'])
def start_download():
    if not download_status['active']:
        download_status['active'] = True
        subprocess.Popen(['/usr/local/bin/gutenberg_downloader.sh'])
    return jsonify({'status': 'started'})

@app.route('/api/stop', methods=['POST'])
def stop_download():
    if download_status['active']:
        download_status['active'] = False
        # Kill wget processes
        os.system("pkill -f 'wget.*gutenberg'")
    return jsonify({'status': 'stopped'})

@app.route('/api/books/<book_id>')
def get_book_info(book_id):
    metadata_file = f"{METADATA_DIR}/{book_id}.json"
    if os.path.exists(metadata_file):
        with open(metadata_file) as f:
            return jsonify(json.load(f))
    return jsonify({'error': 'Book not found'})

if __name__ == '__main__':
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_downloads)
    monitor_thread.daemon = True
    monitor_thread.start()
    
    socketio.run(app, host='0.0.0.0', port=5000) 