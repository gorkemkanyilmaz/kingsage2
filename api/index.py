import os
import sys
import traceback

from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

try:
    server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "server"))
    if os.path.isdir(server_dir) and server_dir not in sys.path:
        sys.path.insert(0, server_dir)

    import api.index as backend
    app = backend.app
except Exception as e:
    err_tb = traceback.format_exc()
    err_str = str(e)

    @app.get("/{full_path:path}")
    def catch_all_debug(full_path: str = ""):
        return JSONResponse(
            status_code=200,
            content={
                "error": "Startup exception caught on Vercel wrapper!",
                "message": err_str,
                "traceback": err_tb,
                "sys_path": sys.path
            }
        )
