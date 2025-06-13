from flask import Flask
from flask_cors import CORS


def create_app():
    app = Flask(__name__)

    # Configure CORS with more specific settings
    CORS(
        app,
        resources={
            r"*": {
                "origins": "*",
                "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                "allow_headers": ["Content-Type", "Authorization"],
                "supports_credentials": True,
            }
        },
    )

    # Register blueprints or routes
    from .routes import main

    app.register_blueprint(main)

    return app
