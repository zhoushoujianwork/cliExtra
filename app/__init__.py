"""
Q Chat Manager Flask Application
"""
from flask import Flask
from flask_socketio import SocketIO
from config.config import Config

socketio = SocketIO()

def create_app(config_class=Config):
    """Application factory pattern"""
    app = Flask(__name__)
    app.config.from_object(config_class)
    
    # Initialize extensions
    socketio.init_app(app, cors_allowed_origins="*")
    
    # Register blueprints
    from app.views.main import bp as main_bp
    from app.views.api import bp as api_bp
    from app.views.websocket import bp as ws_bp
    
    app.register_blueprint(main_bp)
    app.register_blueprint(api_bp, url_prefix='/api')
    app.register_blueprint(ws_bp)
    
    return app
