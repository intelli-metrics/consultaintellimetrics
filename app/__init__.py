from flask import Flask
from flask_cors import CORS

def create_app():
    app = Flask(__name__)
    
    # Configure CORS
    CORS(app, resources={r"*": {"origins": "*"}})
    
    # Register blueprints or routes
    from .routes import main
    app.register_blueprint(main)
    
    return app