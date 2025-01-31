#!/bin/bash
# Web interface configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_webui() {
    log_message "Setting up web interface..."
    
    # Install web server and dependencies
    install_web_packages
    
    # Configure Nginx
    setup_nginx
    
    # Setup Flask application
    setup_flask_app
    
    # Configure SSL
    setup_ssl
    
    # Setup static content
    setup_static_content
    
    # Add Gutenberg browser functions
    setup_gutenberg_browser
    
    log_message "${GREEN}Web interface setup complete${NC}"
}

install_web_packages() {
    apt-get install -y \
        nginx \
        python3-flask \
        python3-flask-sqlalchemy \
        python3-flask-login \
        python3-pip \
        certbot \
        python3-certbot-nginx
        
    pip3 install \
        flask-restful \
        flask-cors \
        gunicorn
}

setup_nginx() {
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/nafo_radio << EOF
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000/api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /static {
        alias /var/www/nafo_radio/static;
    }

    location /docs {
        alias /var/www/nafo_radio/docs;
        autoindex on;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/nafo_radio /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    systemctl restart nginx
}

setup_flask_app() {
    # Create Flask application directory
    mkdir -p /opt/nafo_radio/app
    
    # Create main application file
    cat > /opt/nafo_radio/app/main.py << 'EOF'
from flask import Flask, render_template, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://nafo_admin:secure_password_here@localhost/nafo_radio'

db = SQLAlchemy(app)
login_manager = LoginManager(app)

# Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)

# Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def status():
    return jsonify({
        'system': 'online',
        'raid_status': check_raid_status(),
        'radio_status': check_radio_status(),
        'sensor_status': check_sensor_status()
    })

def check_raid_status():
    with open('/proc/mdstat', 'r') as f:
        return '[UU]' in f.read()

def check_radio_status():
    # Add radio status check logic
    return True

def check_sensor_status():
    # Add sensor status check logic
    return True

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF

    # Create templates
    mkdir -p /opt/nafo_radio/app/templates
    cat > /opt/nafo_radio/app/templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>NAFO Radio Control Panel</title>
    <link rel="stylesheet" href="/static/css/style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>NAFO Radio Control Panel</h1>
        </header>
        <nav>
            <ul>
                <li><a href="#system">System Status</a></li>
                <li><a href="#radio">Radio Control</a></li>
                <li><a href="#sensors">Sensors</a></li>
                <li><a href="#library">Knowledge Library</a></li>
            </ul>
        </nav>
        <main id="content">
            <!-- Dynamic content loaded via JavaScript -->
        </main>
    </div>
    <script src="/static/js/main.js"></script>
</body>
</html>
EOF

    # Create static files
    mkdir -p /opt/nafo_radio/app/static/{css,js,img}
    
    # Create CSS
    cat > /opt/nafo_radio/app/static/css/style.css << 'EOF'
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 0;
    background: #f0f0f0;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

header {
    background: #2c3e50;
    color: white;
    padding: 1em;
    text-align: center;
}

nav {
    background: #34495e;
    padding: 1em;
}

nav ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    justify-content: space-around;
}

nav a {
    color: white;
    text-decoration: none;
}
EOF

    # Create JavaScript
    cat > /opt/nafo_radio/app/static/js/main.js << 'EOF'
document.addEventListener('DOMContentLoaded', function() {
    // Load system status on page load
    fetchSystemStatus();
    
    // Refresh status every 30 seconds
    setInterval(fetchSystemStatus, 30000);
});

function fetchSystemStatus() {
    fetch('/api/status')
        .then(response => response.json())
        .then(data => updateStatus(data))
        .catch(error => console.error('Error:', error));
}

function updateStatus(data) {
    // Update UI with system status
    const content = document.getElementById('content');
    content.innerHTML = `
        <div class="status-panel">
            <h2>System Status</h2>
            <p>RAID: ${data.raid_status ? 'OK' : 'ERROR'}</p>
            <p>Radio: ${data.radio_status ? 'Online' : 'Offline'}</p>
            <p>Sensors: ${data.sensor_status ? 'Active' : 'Inactive'}</p>
        </div>
    `;
}
EOF

    # Create systemd service
    cat > /etc/systemd/system/nafo-webui.service << EOF
[Unit]
Description=NAFO Radio Web Interface
After=network.target

[Service]
User=nafo_admin
WorkingDirectory=/opt/nafo_radio/app
ExecStart=/usr/local/bin/gunicorn -w 4 -b 127.0.0.1:8000 main:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-webui
    systemctl start nafo-webui
}

setup_ssl() {
    # Generate self-signed certificate for development
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nafo-radio.key \
        -out /etc/ssl/certs/nafo-radio.crt \
        -subj "/CN=localhost"
        
    # Update Nginx configuration for SSL
    sed -i 's/listen 80;/listen 443 ssl;/' /etc/nginx/sites-available/nafo_radio
    sed -i '/server_name/a\    ssl_certificate /etc/ssl/certs/nafo-radio.crt;\n    ssl_certificate_key /etc/ssl/private/nafo-radio.key;' \
        /etc/nginx/sites-available/nafo_radio
        
    systemctl restart nginx
}

setup_static_content() {
    # Create directories for static content
    mkdir -p /var/www/nafo_radio/{static,docs}
    
    # Copy static files
    cp -r /opt/nafo_radio/app/static/* /var/www/nafo_radio/static/
    
    # Set permissions
    chown -R nafo_admin:nafo_admin /var/www/nafo_radio
    chmod -R 755 /var/www/nafo_radio
}

# Add Gutenberg browser functions
setup_gutenberg_browser() {
    local port="${1:-8080}"
    local html_template="${SCRIPT_DIR}/web/templates/books.html"
    
    # Start simple Python HTTP server
    python3 -c "
import http.server
import socketserver
import json
import os
import gzip
import re
from urllib.parse import parse_qs, urlparse

LIBRARY_DIR = '${LIBRARY_DIR}'
BOOKS_DIR = '${BOOKS_DIR}'
METADATA_DIR = '${METADATA_DIR}'

class GutenbergHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/':
            self.serve_book_list()
        elif parsed.path == '/search':
            query = parse_qs(parsed.query).get('q', [''])[0]
            self.serve_search_results(query)
        elif parsed.path.startswith('/book/'):
            book_id = parsed.path.split('/')[-1]
            self.serve_book(book_id)
        else:
            self.send_error(404)
    
    def serve_book_list(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        with open('${html_template}', 'r') as f:
            template = f.read()
        
        books = []
        for metadata in os.listdir(METADATA_DIR):
            if metadata.endswith('.json'):
                with open(os.path.join(METADATA_DIR, metadata)) as f:
                    book = json.load(f)
                    books.append(book)
        
        book_list = ''.join([
            f'<div class=\"book\"><h3>{book[\"title\"]}</h3>'
            f'<p>By: {book[\"author\"]}</p>'
            f'<p><a href=\"/book/{book[\"id\"]}\">Read</a></p></div>'
            for book in sorted(books, key=lambda x: x['title'])
        ])
        
        self.wfile.write(template.replace('{{BOOK_LIST}}', book_list).encode())
    
    def serve_book(self, book_id):
        book_path = os.path.join(BOOKS_DIR, f'{book_id}.txt')
        gz_path = book_path + '.gz'
        
        if os.path.exists(gz_path):
            with gzip.open(gz_path, 'rt') as f:
                content = f.read()
        elif os.path.exists(book_path):
            with open(book_path, 'r') as f:
                content = f.read()
        else:
            self.send_error(404)
            return
        
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(content.encode())

with socketserver.TCPServer(('', ${port}), GutenbergHandler) as httpd:
    print(f'Serving Gutenberg library at port {port}')
    httpd.serve_forever()
" &
} 