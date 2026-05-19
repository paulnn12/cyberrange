import os
from flask import Flask


def create_app() -> Flask:
    website_dir = os.path.join(os.path.dirname(__file__), "website")

    app = Flask(
        __name__,
        template_folder=os.path.join(website_dir, "templates"),
        static_folder=os.path.join(website_dir, "static"),
    )

    from .routes import bp
    app.register_blueprint(bp)

    return app
