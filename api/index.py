import os
import sys

# Support Vercel zero-config when Root Directory is set to repo root
server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "server"))
if os.path.isdir(server_dir) and server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from api.index import app
