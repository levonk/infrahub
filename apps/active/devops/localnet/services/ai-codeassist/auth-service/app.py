#!/usr/bin/env python3
"""
Claude Code Authentication Service
Handles API key validation and session management
"""

from flask import Flask, request, jsonify
import jwt
import time
import hashlib
import os
from functools import wraps

app = Flask(__name__)

# Configuration from environment
JWT_SECRET = os.getenv('CLAUDE_CODE_JWT_SECRET', 'default-secret-change-in-production')
API_KEYS_FILE = os.getenv('API_KEYS_FILE', '/app/config/api-keys.json')

# Load API keys (in production, use proper secret management)
def load_api_keys():
    try:
        with open(API_KEYS_FILE, 'r') as f:
            import json
            return json.load(f)
    except:
        return {}

API_KEYS = load_api_keys()

def require_auth(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401

        token = auth_header[7:]  # Remove 'Bearer '
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            # Check expiration
            if payload['exp'] < time.time():
                return jsonify({'error': 'Token expired'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401

        return f(*args, **kwargs)
    return decorated_function

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'claude-code-auth'})

@app.route('/auth', methods=['POST'])
def authenticate():
    data = request.get_json()
    if not data or 'api_key' not in data:
        return jsonify({'error': 'API key required'}), 400

    api_key = data['api_key']
    # Hash the API key for comparison
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    if key_hash not in API_KEYS:
        return jsonify({'error': 'Invalid API key'}), 401

    # Create JWT token
    payload = {
        'user_id': API_KEYS[key_hash]['user_id'],
        'iat': int(time.time()),
        'exp': int(time.time()) + (24 * 60 * 60)  # 24 hours
    }

    token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
    return jsonify({
        'token': token,
        'expires_in': 24 * 60 * 60,
        'user_id': API_KEYS[key_hash]['user_id']
    })

@app.route('/validate', methods=['GET'])
@require_auth
def validate():
    return jsonify({'valid': True})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
