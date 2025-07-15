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

    # Register blueprints for different API versions
    from .routes import main, v2

    app.register_blueprint(main)  # Current routes without prefix (backward compatibility)
    app.register_blueprint(v2, url_prefix="/v2")  # v2 routes with prefix

    return app
