import os

from dotenv import load_dotenv
from app import create_app

load_dotenv()
app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("APP_PORT", 80))
    host = os.getenv("APP_HOST", "192.168.15.200")
    env = os.getenv("ENV", "local")

    debug = False if env != "local" else True
    app.run(host=host, port=port, debug=debug)
