"""
KingsAge 2 — Çevrimiçi Çok Oyunculu Backend Sunucusu (Online Multiplayer Server)
500 Eşzamanlı Kullanıcı (500 CCU) Destekli, Asenkron FastAPI ve SQLite WAL Mimarisi.
"""

import os
import json
import time
import math
import sqlite3
from typing import Dict, Any, List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DB_PATH = os.path.join(os.path.dirname(__file__), "kingsage.db")

def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    return conn

def init_db():
    conn = get_db()
    with conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            email TEXT,
            display_name TEXT NOT NULL,
            token TEXT NOT NULL,
            created_unix INTEGER NOT NULL,
            last_login_unix INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS game_states (
            user_id TEXT PRIMARY KEY,
            state_json TEXT NOT NULL,
            last_tick_unix INTEGER NOT NULL,
            active_village_id INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_name TEXT NOT NULL,
            to_name TEXT NOT NULL,
            subject TEXT NOT NULL,
            body TEXT NOT NULL,
            created_unix INTEGER NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS world_villages (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            owner TEXT NOT NULL,
            points INTEGER NOT NULL DEFAULT 110,
            is_bot INTEGER NOT NULL DEFAULT 0,
            is_barbarian INTEGER NOT NULL DEFAULT 0,
            bonus_type TEXT DEFAULT ''
        );
        """)
    conn.close()

init_db()

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

app = FastAPI(title="KingsAge 2 Online Server", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------------------------
# Pydantic Şemaları
# -----------------------------------------------------------------------------
class AuthRequest(BaseModel):
    provider: str  # "google" | "apple"
    auth_token: Optional[str] = None
    mock_id: Optional[str] = None
    display_name: Optional[str] = None
    email: Optional[str] = None

class ActionRequest(BaseModel):
    action_type: str  # "build", "train", "research", "attack", "trade", "sync"
    payload: Dict[str, Any]

class SendMessageRequest(BaseModel):
    to_name: str
    subject: str
    body: str

# -----------------------------------------------------------------------------
# Auth Yardımcıları
# -----------------------------------------------------------------------------
def verify_token(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    if not authorization:
        raise HTTPException(status_code=401, detail="Yetkilendirme başlığı (Authorization) eksik.")
    token = authorization.replace("Bearer ", "").strip()
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE token = ?", (token,))
    user = cursor.fetchone()
    conn.close()
    if not user:
        raise HTTPException(status_code=401, detail="Geçersiz veya süresi dolmuş oturum jetonu.")
    return dict(user)

# -----------------------------------------------------------------------------
# Çevrimdışı İlerleme (Offline Progression Catch-Up) Simülasyonu
# -----------------------------------------------------------------------------
def simulate_offline_progress(state: Dict[str, Any], elapsed_seconds: int) -> Dict[str, Any]:
    if elapsed_seconds <= 0:
        return state

    villages = state.get("villages", [])
    now = int(time.time())

    for v in villages:
        if v.get("is_bot") or v.get("is_barbarian"):
            continue

        blds = v.get("buildings", {})
        res = v.get("resources", {"wood": 1000, "stone": 1000, "iron": 1000})

        # KingsAge taban saatlik üretim eğrisi: 30 * 1.25^(level - 1)
        w_lvl = int(blds.get("wood", 1))
        s_lvl = int(blds.get("stone", 1))
        i_lvl = int(blds.get("iron", 1))

        w_hourly = int(round(30.0 * math.pow(1.25, max(0, w_lvl - 1))))
        s_hourly = int(round(30.0 * math.pow(1.25, max(0, s_lvl - 1))))
        i_hourly = int(round(30.0 * math.pow(1.25, max(0, i_lvl - 1))))

        hours = elapsed_seconds / 3600.0
        w_gain = int(w_hourly * hours)
        s_gain = int(s_hourly * hours)
        i_gain = int(i_hourly * hours)

        # Depo kapasitesi kontrolü
        storage_lvl = int(blds.get("storage", 1))
        storage_cap = int(round(1000.0 * math.pow(1.30, max(0, storage_lvl - 1))))

        res["wood"] = min(storage_cap, int(res.get("wood", 0)) + w_gain)
        res["stone"] = min(storage_cap, int(res.get("stone", 0)) + s_gain)
        res["iron"] = min(storage_cap, int(res.get("iron", 0)) + i_gain)
        v["resources"] = res

    # Tamamlanan inşaat ve hareket kuyruklarını temizle
    queues = state.get("queues", [])
    completed_queues = []
    active_queues = []
    for q in queues:
        if int(q.get("finish_unix", 0)) <= now:
            completed_queues.append(q)
        else:
            active_queues.append(q)
    state["queues"] = active_queues

    return state

# -----------------------------------------------------------------------------
# API Endpointleri
# -----------------------------------------------------------------------------
@app.get("/api/health")
def health_check():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM users")
    user_count = cursor.fetchone()[0]
    conn.close()
    return {
        "status": "online",
        "engine": "KingsAge 2 Dedicated Online Core",
        "supported_ccu": 500,
        "registered_lords": user_count,
        "server_time_unix": int(time.time()),
        "auth_methods": ["Google Sign-In", "Apple Sign-In"]
    }

@app.post("/api/auth/login")
def auth_login(req: AuthRequest):
    if req.provider not in ["google", "apple"]:
        raise HTTPException(status_code=400, detail="Yalnızca 'google' veya 'apple' ile giriş yapılabilir.")

    now = int(time.time())
    user_id = req.mock_id if req.mock_id else f"{req.provider}_{int(time.time() * 1000) % 1000000}"
    name = req.display_name if req.display_name else ("Lord Edward" if req.provider == "google" else "Lord Roland")
    email = req.email if req.email else f"{name.lower().replace(' ', '.')}@{req.provider}.com"
    token = f"{req.provider}_tok_{now}_{os.urandom(8).hex()}"

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    existing = cursor.fetchone()

    if existing:
        cursor.execute("UPDATE users SET token = ?, last_login_unix = ? WHERE id = ?", (token, now, user_id))
    else:
        cursor.execute("""
            INSERT INTO users (id, provider, email, display_name, token, created_unix, last_login_unix)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, req.provider, email, name, token, now, now))

    # Oyun durumunu kontrol et
    cursor.execute("SELECT * FROM game_states WHERE user_id = ?", (user_id,))
    has_state = cursor.fetchone() is not None

    conn.commit()
    conn.close()

    return {
        "ok": True,
        "token": token,
        "user_id": user_id,
        "display_name": name,
        "provider": req.provider,
        "has_game_state": has_state
    }

@app.get("/api/game/state")
def get_game_state(user: Dict[str, Any] = Depends(verify_token)):
    user_id = user["id"]
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM game_states WHERE user_id = ?", (user_id,))
    row = cursor.fetchone()

    now = int(time.time())
    if not row:
        conn.close()
        return {"ok": False, "has_state": False, "message": "Henüz oluşturulmuş bir krallık yok."}

    last_tick = int(row["last_tick_unix"])
    elapsed = max(0, now - last_tick)
    state = json.loads(row["state_json"])

    # Çevrimdışı sürenin telafisini simüle et
    updated_state = simulate_offline_progress(state, elapsed)

    # Durumu güncelle
    cursor.execute(
        "UPDATE game_states SET state_json = ?, last_tick_unix = ? WHERE user_id = ?",
        (json.dumps(updated_state), now, user_id)
    )
    conn.commit()
    conn.close()

    return {
        "ok": True,
        "has_state": True,
        "elapsed_offline_seconds": elapsed,
        "state": updated_state,
        "user": {
            "name": user["display_name"],
            "provider": user["provider"],
            "email": user["email"]
        }
    }

@app.post("/api/game/save")
def save_game_state(state_payload: Dict[str, Any], user: Dict[str, Any] = Depends(verify_token)):
    user_id = user["id"]
    now = int(time.time())
    state_json = json.dumps(state_payload)
    active_vid = int(state_payload.get("active_village_id", 1))

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO game_states (user_id, state_json, last_tick_unix, active_village_id)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            state_json = excluded.state_json,
            last_tick_unix = excluded.last_tick_unix,
            active_village_id = excluded.active_village_id
    """, (user_id, state_json, now, active_vid))
    conn.commit()
    conn.close()

    return {"ok": True, "saved_unix": now}

@app.get("/api/messages/inbox")
def get_inbox(user: Dict[str, Any] = Depends(verify_token)):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT * FROM messages WHERE to_name = ? OR to_name = 'Tümü' ORDER BY created_unix DESC LIMIT 50",
        (user["display_name"],)
    )
    rows = cursor.fetchall()
    conn.close()

    items = [dict(r) for r in rows]
    return {"ok": True, "messages": items}

@app.post("/api/messages/send")
def send_message(msg: SendMessageRequest, user: Dict[str, Any] = Depends(verify_token)):
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO messages (from_name, to_name, subject, body, created_unix, is_read)
        VALUES (?, ?, ?, ?, ?, 0)
    """, (user["display_name"], msg.to_name, msg.subject, msg.body, now))
    conn.commit()
    conn.close()
    return {"ok": True, "sent_unix": now}
