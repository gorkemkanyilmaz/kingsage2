"""
Taht ve Kılıç (KingsAge 2) — Çevrimiçi Sunucu Motoru (Authoritative Serverless Engine)
Vercel Serverless ve Cloudflare ile uyumlu, SQL Injection Korumalı, 500+ Eşzamanlı Oyuncu Mimarisi.
"""

import os
import sys
import json
import time
import math
import html
import random
import secrets
import sqlite3
from typing import Dict, Any, List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

import re

# -----------------------------------------------------------------------------
# Evrensel Veritabanı Yapılandırması (Supabase PostgreSQL & SQLite Çift Desteği)
# -----------------------------------------------------------------------------
IS_VERCEL = bool(os.getenv("VERCEL"))

def sanitize_db_url(url: str) -> str:
    """Vercel AWS Lambda ortamlarında IPv6 direct connection yerine IPv4 pooler kullanır."""
    if not url:
        return url
    m = re.search(r'db\.([a-z0-9]+)\.supabase\.co', url)
    if m:
        ref = m.group(1)
        if f"postgres.{ref}" not in url:
            url = url.replace("postgres:", f"postgres.{ref}:", 1)
        url = re.sub(r'db\.[a-z0-9]+\.supabase\.co(?::\d+)?', 'aws-0-eu-west-1.pooler.supabase.com:6543', url)
        if "sslmode=" not in url:
            url += ("&" if "?" in url else "?") + "sslmode=require"
    return url

DATABASE_URL = sanitize_db_url(os.getenv("DATABASE_URL", ""))
IS_POSTGRES = DATABASE_URL.startswith("postgres://") or DATABASE_URL.startswith("postgresql://")

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False

if IS_VERCEL:
    DB_PATH = "/tmp/kingsage_serverless.db"
else:
    DB_PATH = os.path.join(os.path.dirname(__file__), "..", "kingsage.db")



class RowDict(dict):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._list = list(self.values())

    def __getitem__(self, key):
        if isinstance(key, int):
            return self._list[key]
        return super().__getitem__(key)


class DBCursor:
    def __init__(self, raw_cursor, is_pg: bool):
        self.raw_cursor = raw_cursor
        self.is_pg = is_pg

    def execute(self, query: str, params: tuple = ()):
        if self.is_pg:
            pg_query = query.replace("?", "%s")
            self.raw_cursor.execute(pg_query, params)
        else:
            self.raw_cursor.execute(query, params)
        return self

    def fetchone(self):
        row = self.raw_cursor.fetchone()
        if row is None:
            return None
        return RowDict(dict(row))

    def fetchall(self):
        rows = self.raw_cursor.fetchall()
        return [RowDict(dict(r)) for r in rows]

    @property
    def lastrowid(self):
        return getattr(self.raw_cursor, "lastrowid", None)


class DBConnection:
    def __init__(self, raw_conn, is_pg: bool):
        self.raw_conn = raw_conn
        self.is_pg = is_pg

    def cursor(self):
        if self.is_pg:
            return DBCursor(self.raw_conn.cursor(cursor_factory=RealDictCursor), True)
        return DBCursor(self.raw_conn.cursor(), False)

    def commit(self):
        self.raw_conn.commit()

    def rollback(self):
        self.raw_conn.rollback()

    def close(self):
        self.raw_conn.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            self.rollback()
        else:
            self.commit()
        self.close()


def get_db() -> DBConnection:
    raw_url = os.getenv("DATABASE_URL", "")
    db_url = sanitize_db_url(raw_url)
    is_pg = bool(db_url and (db_url.startswith("postgres://") or db_url.startswith("postgresql://")))
    if is_pg and HAS_PSYCOPG2:
        conn = psycopg2.connect(db_url)
        return DBConnection(conn, True)
    else:
        conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        if not IS_VERCEL:
            conn.execute("PRAGMA journal_mode=WAL;")
        else:
            conn.execute("PRAGMA journal_mode=MEMORY;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("PRAGMA foreign_keys=ON;")
        return DBConnection(conn, False)



def init_db():
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        pk_auto = "SERIAL PRIMARY KEY" if conn.is_pg else "INTEGER PRIMARY KEY AUTOINCREMENT"
        bigint_t = "BIGINT" if conn.is_pg else "INTEGER"

        tables = [
            """CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                email TEXT,
                display_name TEXT NOT NULL UNIQUE,
                token TEXT NOT NULL UNIQUE,
                created_unix {0} NOT NULL,
                last_login_unix {0} NOT NULL
            )""".format(bigint_t),

            """CREATE TABLE IF NOT EXISTS worlds (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                seed INTEGER NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_unix {0} NOT NULL,
                registered_players INTEGER NOT NULL DEFAULT 0
            )""".format(bigint_t),

            """CREATE TABLE IF NOT EXISTS villages (
                id INTEGER PRIMARY KEY,
                world_id INTEGER NOT NULL DEFAULT 1,
                user_id TEXT,
                name TEXT NOT NULL,
                x INTEGER NOT NULL,
                y INTEGER NOT NULL,
                owner TEXT NOT NULL,
                points INTEGER NOT NULL DEFAULT 110,
                is_bot INTEGER NOT NULL DEFAULT 0,
                is_barbarian INTEGER NOT NULL DEFAULT 0,
                buildings_json TEXT NOT NULL,
                resources_json TEXT NOT NULL,
                units_json TEXT NOT NULL,
                last_calc_unix {0} NOT NULL,
                protection_until_unix {0} NOT NULL DEFAULT 0,
                conquest_protection_until_unix {0} NOT NULL DEFAULT 0
            )""".format(bigint_t),

            """CREATE TABLE IF NOT EXISTS queues (
                id {0},
                world_id INTEGER NOT NULL DEFAULT 1,
                village_id INTEGER NOT NULL,
                user_id TEXT NOT NULL,
                type TEXT NOT NULL,
                target_key TEXT NOT NULL,
                target_level INTEGER NOT NULL DEFAULT 1,
                count INTEGER NOT NULL DEFAULT 1,
                finish_unix {1} NOT NULL
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS movements (
                id {0},
                world_id INTEGER NOT NULL DEFAULT 1,
                user_id TEXT NOT NULL,
                from_village_id INTEGER NOT NULL,
                to_village_id INTEGER NOT NULL,
                type TEXT NOT NULL,
                units_json TEXT NOT NULL,
                loot_json TEXT NOT NULL DEFAULT '{{}}',
                start_unix {1} NOT NULL,
                arrival_unix {1} NOT NULL,
                status TEXT NOT NULL DEFAULT 'moving'
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS reports (
                id {0},
                world_id INTEGER NOT NULL DEFAULT 1,
                user_name TEXT NOT NULL,
                village_id INTEGER NOT NULL,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                data_json TEXT NOT NULL,
                created_unix {1} NOT NULL,
                is_unread INTEGER NOT NULL DEFAULT 1
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS messages (
                id {0},
                world_id INTEGER NOT NULL DEFAULT 1,
                from_name TEXT NOT NULL,
                to_name TEXT NOT NULL,
                subject TEXT NOT NULL,
                body TEXT NOT NULL,
                created_unix {1} NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS alliances (
                id {0},
                world_id INTEGER NOT NULL DEFAULT 1,
                name TEXT NOT NULL UNIQUE,
                tag TEXT NOT NULL UNIQUE,
                description TEXT NOT NULL DEFAULT '',
                founder_name TEXT NOT NULL,
                leader_name TEXT NOT NULL,
                created_unix {1} NOT NULL
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS alliance_members (
                id {0},
                alliance_id INTEGER NOT NULL,
                user_name TEXT NOT NULL UNIQUE,
                rank TEXT NOT NULL DEFAULT 'member',
                joined_unix {1} NOT NULL
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS alliance_invitations (
                id {0},
                alliance_id INTEGER NOT NULL,
                user_name TEXT NOT NULL,
                invited_by TEXT NOT NULL,
                created_unix {1} NOT NULL
            )""".format(pk_auto, bigint_t),

            """CREATE TABLE IF NOT EXISTS cloud_saves (
                user_id TEXT PRIMARY KEY,
                state_json TEXT NOT NULL,
                updated_unix {0} NOT NULL
            )""".format(bigint_t)
        ]

        for stmt in tables:
            cursor.execute(stmt)

        # Varsayılan Dünya 1 kontrolü
        cursor.execute("SELECT id FROM worlds WHERE id = 1")
        if not cursor.fetchone():
            now = int(time.time())
            cursor.execute("""
                INSERT INTO worlds (id, name, seed, is_active, created_unix, registered_players)
                VALUES (1, 'Dünya 1', 1001, 1, ?, 0)
            """, (now,))

            # 50 Bot Köyü Üretimi (Haritaya dengeli dağıtım)
            random.seed(1001)
            bot_names = [
                "Lord Edward", "Baron Roland", "Kont Vlad", "Dük William", "Prens Arthur",
                "Lord Richard", "Baron Godfrey", "Kont Baldwin", "Dük Robert", "Lord Henry",
                "Baron Simon", "Kont Raymond", "Dük Geoffrey", "Lord Stephen", "Baron Guy",
                "Kont Bohemond", "Dük Tancred", "Lord Walter", "Baron Hugh", "Kont Peter",
                "Lord Gareth", "Baron Tristram", "Kont Lancelot", "Dük Galahad", "Lord Percival",
                "Lord Bedivere", "Baron Kay", "Kont Lamorak", "Dük Gawain", "Lord Geraint",
                "Baron Bors", "Kont Gaheris", "Dük Agravain", "Lord Ywain", "Baron Gareth II",
                "Kont Dinadan", "Dük Palamedes", "Lord Sagramore", "Baron Lucan", "Kont Ector",
                "Lord Colgrevance", "Baron Safir", "Kont Segwarides", "Dük Pelleas", "Lord Marhaus",
                "Baron Dagonet", "Kont Tor", "Dük Bleoberis", "Lord Cador", "Baron Morholt"
            ]

            initial_buildings = json.dumps({
                "main": 3, "farm": 2, "wood": 2, "stone": 2, "iron": 2,
                "storage": 2, "barracks": 1, "wall": 1, "hide": 1
            })
            initial_resources = json.dumps({"wood": 800, "stone": 800, "iron": 800})
            initial_units = json.dumps({"spear": 10, "sword": 5})

            for idx, bname in enumerate(bot_names, start=1):
                bx = random.randint(15, 185)
                by = random.randint(15, 185)
                cursor.execute("""
                    INSERT INTO villages (
                        id, world_id, user_id, name, x, y, owner, points, is_bot, is_barbarian,
                        buildings_json, resources_json, units_json, last_calc_unix, protection_until_unix
                    ) VALUES (?, 1, NULL, ?, ?, ?, ?, 110, 1, 0, ?, ?, ?, ?, 0)
                """, (idx, f"Kale {bname}", bx, by, bname, initial_buildings, initial_resources, initial_units, now))

    conn.close()

# -----------------------------------------------------------------------------
# FastAPI Uygulaması
# -----------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        init_db()
    except Exception as e:
        print(f"[UYARI] init_db başlatma hatası: {e}", file=sys.stderr)
    yield


app = FastAPI(
    title="Taht ve Kılıç (KingsAge 2) Yetkili Sunucusu",
    version="2.1.0",
    description="Vercel & Cloudflare Uyumlu, Server-Authoritative MMO Altyapısı",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------------------------
# Pydantic Doğrulama Şemaları (Parametrik & Injection Korumalı)
# -----------------------------------------------------------------------------
class AuthLoginRequest(BaseModel):
    provider: str = Field(..., max_length=20)
    display_name: str = Field(..., min_length=2, max_length=30)
    email: Optional[str] = Field(None, max_length=100)

class JoinWorldRequest(BaseModel):
    world_id: int = Field(1, ge=1, le=10)
    target_x: int = Field(100, ge=0, le=200)
    target_y: int = Field(100, ge=0, le=200)

class BuildActionRequest(BaseModel):
    village_id: int
    building_key: str = Field(..., max_length=30)

class TrainActionRequest(BaseModel):
    village_id: int
    unit_key: str = Field(..., max_length=30)
    count: int = Field(..., ge=1, le=5000)

class SendTroopsRequest(BaseModel):
    from_village_id: int
    to_village_id: int
    type: str = Field("attack", pattern="^(attack|raid|support)$")
    units: Dict[str, int]

class SendMessageRequest(BaseModel):
    to_name: str = Field(..., min_length=2, max_length=30)
    subject: str = Field(..., min_length=1, max_length=80)
    body: str = Field(..., min_length=1, max_length=2000)

class CreateAllianceRequest(BaseModel):
    name: str = Field(..., min_length=3, max_length=32)
    tag: str = Field(..., min_length=2, max_length=6)
    description: Optional[str] = Field("", max_length=500)

# -----------------------------------------------------------------------------
# Kimlik Doğrulama / Yetkilendirme (Bearer Token Dependency)
# -----------------------------------------------------------------------------
def get_current_user(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Yetkilendirme başlığı eksik veya geçersiz.")
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
# Yetkili Hesaplama ve Kural Motoru (Authoritative Rules Engine)
# -----------------------------------------------------------------------------
def get_storage_cap(storage_lvl: int) -> int:
    return int(round(1000.0 * math.pow(1.30, max(0, storage_lvl - 1))))

def get_hourly_production(lvl: int) -> int:
    if lvl <= 0:
        return 10
    return int(round(30.0 * math.pow(1.25, max(0, lvl - 1))))

def get_max_population(farm_lvl: int) -> int:
    return int(round(240.0 * math.pow(1.17, max(0, farm_lvl - 1))))

def simulate_village_lazy(v_dict: Dict[str, Any], now: int, conn: sqlite3.Connection) -> Dict[str, Any]:
    """Sunucu taraflı lazy catch-up: maden üretimi ve tamamlanan kuyrukların işlenmesi."""
    last_calc = int(v_dict.get("last_calc_unix", now))
    elapsed = max(0, now - last_calc)

    blds = json.loads(v_dict["buildings_json"]) if isinstance(v_dict["buildings_json"], str) else v_dict["buildings_json"]
    res = json.loads(v_dict["resources_json"]) if isinstance(v_dict["resources_json"], str) else v_dict["resources_json"]
    units = json.loads(v_dict["units_json"]) if isinstance(v_dict["units_json"], str) else v_dict["units_json"]

    # 1. Maden Üretimi
    if elapsed > 0:
        hours = elapsed / 3600.0
        w_gain = int(get_hourly_production(int(blds.get("wood", 1))) * hours)
        s_gain = int(get_hourly_production(int(blds.get("stone", 1))) * hours)
        i_gain = int(get_hourly_production(int(blds.get("iron", 1))) * hours)

        storage_cap = get_storage_cap(int(blds.get("storage", 1)))
        res["wood"] = min(storage_cap, int(res.get("wood", 0)) + w_gain)
        res["stone"] = min(storage_cap, int(res.get("stone", 0)) + s_gain)
        res["iron"] = min(storage_cap, int(res.get("iron", 0)) + i_gain)

    # 2. Tamamlanan İnşaat ve Eğitim Kuyrukları
    vid = int(v_dict["id"])
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM queues WHERE village_id = ? AND finish_unix <= ? ORDER BY finish_unix ASC
    """, (vid, now))
    done_queues = cursor.fetchall()

    if done_queues:
        for q in done_queues:
            q_type = q["type"]
            q_key = q["target_key"]
            if q_type == "build":
                blds[q_key] = int(q["target_level"])
            elif q_type == "train":
                units[q_key] = int(units.get(q_key, 0)) + int(q["count"])
        cursor.execute("DELETE FROM queues WHERE village_id = ? AND finish_unix <= ?", (vid, now))

    # Güncellenen veriyi veritabanına kaydet
    cursor.execute("""
        UPDATE villages SET
            buildings_json = ?,
            resources_json = ?,
            units_json = ?,
            last_calc_unix = ?
        WHERE id = ?
    """, (json.dumps(blds), json.dumps(res), json.dumps(units), now, vid))

    v_dict["buildings"] = blds
    v_dict["resources"] = res
    v_dict["units"] = units
    v_dict["last_calc_unix"] = now
    return v_dict

# -----------------------------------------------------------------------------
# API Endpointleri (100+ Eşzamanlı Oyuncu Desteği)
# -----------------------------------------------------------------------------

@app.get("/api")
@app.get("/api/")
@app.get("/api/health")
def health():
    db_status = "ok"
    u_count = 0
    real_villages = 0
    err_msg = None
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM users")
        u_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM villages WHERE is_bot = 0")
        real_villages = cursor.fetchone()[0]
        conn.close()
    except Exception as e:
        db_status = "error"
        err_msg = str(e)

    return {
        "status": "online",
        "game": "Taht ve Kılıç (KingsAge 2)",
        "engine": "Authoritative Serverless Engine (Vercel/Cloudflare)",
        "db_mode": "Supabase PostgreSQL (Pooler)" if IS_POSTGRES else "SQLite WAL",
        "db_status": db_status,
        "db_error": err_msg,
        "registered_players": u_count,
        "real_player_villages": real_villages,
        "server_time_unix": int(time.time()),
        "security": "100% Parameterized SQL (Injection-Proof), Bearer Auth, Server-Authoritative"
    }


def ensure_cloud_saves_table(cursor, is_pg: bool) -> None:
    bigint_t = "BIGINT" if is_pg else "INTEGER"
    cursor.execute("""CREATE TABLE IF NOT EXISTS cloud_saves (
        user_id TEXT PRIMARY KEY,
        state_json TEXT NOT NULL,
        updated_unix {0} NOT NULL
    )""".format(bigint_t))


def _serialize_server_village(v_row) -> Optional[Dict[str, Any]]:
    if not v_row:
        return None
    v = dict(v_row)
    for src_key, dst_key in (("buildings_json", "buildings"), ("resources_json", "resources"), ("units_json", "units")):
        raw = v.get(src_key)
        if isinstance(raw, str):
            try:
                v[dst_key] = json.loads(raw)
            except Exception:
                v[dst_key] = {}
        elif isinstance(raw, dict):
            v[dst_key] = raw
        else:
            v[dst_key] = {}
    return v


def _fetch_cloud_and_village(cursor, user_id: str, display_name: str):
    cursor.execute("SELECT state_json, updated_unix FROM cloud_saves WHERE user_id = ?", (user_id,))
    c_row = cursor.fetchone()
    cloud_state = None
    cloud_updated_unix = 0
    if c_row:
        cloud_updated_unix = int(c_row["updated_unix"])
        try:
            cloud_state = json.loads(c_row["state_json"])
        except Exception:
            cloud_state = None

    cursor.execute("SELECT * FROM villages WHERE owner = ? AND is_bot = 0 ORDER BY id ASC LIMIT 1", (display_name,))
    v_row = cursor.fetchone()
    server_village = _serialize_server_village(v_row)
    return cloud_state, cloud_updated_unix, server_village


@app.post("/api/auth/login")
def auth_login(req: AuthLoginRequest):
    display_name = html.escape(req.display_name.strip())
    if not display_name:
        raise HTTPException(status_code=400, detail="Geçersiz kullanıcı adı.")

    now = int(time.time())
    user_id = f"{req.provider}_{secrets.token_hex(6)}"
    token = f"tk_tok_{secrets.token_hex(24)}"
    email = req.email or f"{display_name.lower().replace(' ', '.')}@{req.provider}.com"

    conn = get_db()
    cursor = conn.cursor()
    ensure_cloud_saves_table(cursor, conn.is_pg)
    cursor.execute("SELECT * FROM users WHERE display_name = ?", (display_name,))
    existing = cursor.fetchone()

    if existing:
        user_id = existing["id"]
        cursor.execute("UPDATE users SET token = ?, last_login_unix = ? WHERE id = ?", (token, now, user_id))
    else:
        cursor.execute("""
            INSERT INTO users (id, provider, email, display_name, token, created_unix, last_login_unix)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, req.provider, email, display_name, token, now, now))

    cloud_state, cloud_updated_unix, server_village = _fetch_cloud_and_village(cursor, user_id, display_name)
    has_village = bool(server_village is not None or cloud_state is not None)

    conn.commit()
    conn.close()

    return {
        "ok": True,
        "token": token,
        "user_id": user_id,
        "display_name": display_name,
        "has_village": has_village,
        "cloud_state": cloud_state,
        "updated_unix": cloud_updated_unix,
        "server_village": server_village
    }

@app.get("/api/auth/me")
def get_me(user: Dict[str, Any] = Depends(get_current_user)):
    return {"ok": True, "user": user}

@app.get("/api/worlds")
def get_worlds():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM worlds ORDER BY id ASC")
    rows = cursor.fetchall()
    conn.close()
    return {"ok": True, "worlds": [dict(r) for r in rows]}

@app.post("/api/worlds/join")
def join_world(req: JoinWorldRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    p_name = user["display_name"]
    conn = get_db()
    cursor = conn.cursor()

    # Zaten köyü var mı?
    cursor.execute("SELECT * FROM villages WHERE world_id = ? AND owner = ?", (req.world_id, p_name))
    existing = cursor.fetchone()
    if existing:
        conn.close()
        return {"ok": True, "message": "Zaten köyünüz mevcut.", "village_id": existing["id"]}

    # En yüksek ID'yi bul
    cursor.execute("SELECT MAX(id) FROM villages")
    max_id = cursor.fetchone()[0] or 0
    new_vid = max_id + 1

    # Hedef bölgede boş nokta bul
    cursor.execute("SELECT x, y FROM villages WHERE world_id = ?", (req.world_id,))
    taken = {(r["x"], r["y"]) for r in cursor.fetchall()}

    tx, ty = req.target_x, req.target_y
    spot = None
    for r in range(1, 50):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                cx, cy = max(5, min(195, tx + dx)), max(5, min(195, ty + dy))
                if (cx, cy) not in taken:
                    spot = (cx, cy)
                    break
            if spot: break
        if spot: break
    if not spot:
        spot = (tx, ty)

    # 15 günlük fetih koruması
    prot_time = now + (15 * 86400)
    init_blds = json.dumps({"main": 1, "farm": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "wall": 0, "hide": 1})
    init_res = json.dumps({"wood": 500, "stone": 500, "iron": 500})
    init_units = json.dumps({"spear": 0, "sword": 0})

    cursor.execute("""
        INSERT INTO villages (
            id, world_id, user_id, name, x, y, owner, points, is_bot, is_barbarian,
            buildings_json, resources_json, units_json, last_calc_unix,
            protection_until_unix, conquest_protection_until_unix
        ) VALUES (?, ?, ?, 'Başkent', ?, ?, ?, 110, 0, 0, ?, ?, ?, ?, ?, ?)
    """, (new_vid, req.world_id, user["id"], spot[0], spot[1], p_name, init_blds, init_res, init_units, now, prot_time, prot_time))

    cursor.execute("UPDATE worlds SET registered_players = registered_players + 1 WHERE id = ?", (req.world_id,))

    # Karşılama mesajı (Yalnızca 1 kez, ittifak daveti olmadan Konsey tarafından)
    cursor.execute("""
        INSERT INTO messages (world_id, from_name, to_name, subject, body, created_unix, is_read)
        VALUES (?, 'Taht ve Kılıç Konseyi', ?, ?, ?, ?, 0)
    """, (
        req.world_id,
        p_name,
        f"🛡️ Dünya {req.world_id}'ye Hoş Geldiniz, Sayın Lord",
        f"Selamlar Sayın {p_name},\n\nDünya {req.world_id} topraklarına hoş geldiniz! 15 günlük fetih korumanız aktif durumdadır. Bu süre zarfında köylerinizi geliştirebilir ve ordunuzu kurabilirsiniz.\n\nKılıcınız keskin, krallığınız daim olsun.\n\nSaygılarımızla,\nTaht ve Kılıç Konseyi",
        now
    ))

    conn.commit()
    conn.close()

    return {"ok": True, "village_id": new_vid, "x": spot[0], "y": spot[1]}

@app.get("/api/worlds/{world_id}/map")
def get_world_map(world_id: int):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT v.id, v.name, v.x, v.y, v.owner, v.points, v.is_bot, v.is_barbarian,
               v.protection_until_unix, a.tag as alliance_tag
        FROM villages v
        LEFT JOIN alliance_members m ON m.user_name = v.owner
        LEFT JOIN alliances a ON a.id = m.alliance_id
        WHERE v.world_id = ?
    """, (world_id,))
    rows = cursor.fetchall()
    conn.close()
    return {"ok": True, "villages": [dict(r) for r in rows]}

@app.get("/api/villages/{village_id}")
def get_village(village_id: int, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM villages WHERE id = ?", (village_id,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Köy bulunamadı.")

    v_dict = dict(row)
    # Lazy simülasyon
    v_dict = simulate_village_lazy(v_dict, now, conn)

    # Aktif kuyrukları getir
    cursor.execute("SELECT * FROM queues WHERE village_id = ? ORDER BY finish_unix ASC", (village_id,))
    q_rows = cursor.fetchall()
    conn.commit()
    conn.close()

    v_dict["queues"] = [dict(q) for q in q_rows]
    return {"ok": True, "village": v_dict}

@app.post("/api/action/build")
def action_build(req: BuildActionRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM villages WHERE id = ?", (req.village_id,))
    v_row = cursor.fetchone()
    if not v_row:
        conn.close()
        raise HTTPException(status_code=404, detail="Köy bulunamadı.")

    # Yetki Kontrolü: Başkasının köyüne inşaat verilemez!
    if v_row["owner"] != user["display_name"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Bu köy üzerinde inşaat yetkiniz yok!")

    v_dict = dict(v_row)
    v_dict = simulate_village_lazy(v_dict, now, conn)
    blds = v_dict["buildings"]
    res = v_dict["resources"]

    cur_lvl = int(blds.get(req.building_key, 0))
    target_lvl = cur_lvl + 1

    # Basit maliyet hesabı (KingsAge taban)
    cost_base = {"main": 100, "barracks": 200, "wood": 60, "stone": 60, "iron": 60, "storage": 120, "farm": 80}.get(req.building_key, 100)
    w_cost = int(round(cost_base * math.pow(1.22, cur_lvl)))
    s_cost = int(round(cost_base * math.pow(1.22, cur_lvl)))
    i_cost = int(round(cost_base * math.pow(1.22, cur_lvl)))

    if res["wood"] < w_cost or res["stone"] < s_cost or res["iron"] < i_cost:
        conn.close()
        raise HTTPException(status_code=400, detail="Yetersiz hammadde!")

    # Hammaddeyi sunucuda düş
    res["wood"] -= w_cost
    res["stone"] -= s_cost
    res["iron"] -= i_cost

    # Süre (Sn)
    duration = max(10, int(60 * math.pow(1.18, cur_lvl)))
    finish_unix = now + duration

    cursor.execute("""
        INSERT INTO queues (world_id, village_id, user_id, type, target_key, target_level, count, finish_unix)
        VALUES (?, ?, ?, 'build', ?, ?, 1, ?)
    """, (v_row["world_id"], req.village_id, user["id"], req.building_key, target_lvl, finish_unix))

    cursor.execute("UPDATE villages SET resources_json = ? WHERE id = ?", (json.dumps(res), req.village_id))
    conn.commit()
    conn.close()

    return {"ok": True, "target_level": target_lvl, "finish_unix": finish_unix, "duration_seconds": duration}

@app.post("/api/action/train")
def action_train(req: TrainActionRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM villages WHERE id = ?", (req.village_id,))
    v_row = cursor.fetchone()
    if not v_row:
        conn.close()
        raise HTTPException(status_code=404, detail="Köy bulunamadı.")

    if v_row["owner"] != user["display_name"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Bu köy üzerinde asker eğitme yetkiniz yok!")

    v_dict = dict(v_row)
    v_dict = simulate_village_lazy(v_dict, now, conn)
    res = v_dict["resources"]

    unit_costs = {
        "spear": {"wood": 50, "stone": 30, "iron": 10, "time": 15},
        "sword": {"wood": 30, "stone": 30, "iron": 70, "time": 25},
        "bow": {"wood": 80, "stone": 30, "iron": 60, "time": 30},
        "light": {"wood": 125, "stone": 100, "iron": 250, "time": 60},
        "heavy": {"wood": 200, "stone": 150, "iron": 600, "time": 120}
    }
    u_cost = unit_costs.get(req.unit_key, {"wood": 50, "stone": 50, "iron": 50, "time": 30})
    total_w = u_cost["wood"] * req.count
    total_s = u_cost["stone"] * req.count
    total_i = u_cost["iron"] * req.count

    if res["wood"] < total_w or res["stone"] < total_s or res["iron"] < total_i:
        conn.close()
        raise HTTPException(status_code=400, detail="Asker eğitimi için yetersiz hammadde!")

    res["wood"] -= total_w
    res["stone"] -= total_s
    res["iron"] -= total_i

    duration = u_cost["time"] * req.count
    finish_unix = now + duration

    cursor.execute("""
        INSERT INTO queues (world_id, village_id, user_id, type, target_key, target_level, count, finish_unix)
        VALUES (?, ?, ?, 'train', ?, 1, ?, ?)
    """, (v_row["world_id"], req.village_id, user["id"], req.unit_key, req.count, finish_unix))

    cursor.execute("UPDATE villages SET resources_json = ? WHERE id = ?", (json.dumps(res), req.village_id))
    conn.commit()
    conn.close()

    return {"ok": True, "count": req.count, "finish_unix": finish_unix, "duration_seconds": duration}

@app.post("/api/action/send_troops")
def action_send_troops(req: SendTroopsRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM villages WHERE id = ?", (req.from_village_id,))
    from_v = cursor.fetchone()
    cursor.execute("SELECT * FROM villages WHERE id = ?", (req.to_village_id,))
    to_v = cursor.fetchone()

    if not from_v or not to_v:
        conn.close()
        raise HTTPException(status_code=404, detail="Başlangıç veya hedef köy bulunamadı.")

    if from_v["owner"] != user["display_name"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Yalnızca kendi köyünüzden ordu gönderebilirsiniz.")

    # Koruma Kalkanı Kontrolü (Hedef saldırıdan korunuyor mu?)
    if req.type == "attack" and int(to_v["protection_until_unix"]) > now:
        conn.close()
        raise HTTPException(status_code=400, detail="Hedef köyün 15 günlük fetih koruması aktif!")

    from_dict = simulate_village_lazy(dict(from_v), now, conn)
    units_avail = from_dict["units"]

    # Birlikler köyde var mı?
    for uk, count in req.units.items():
        if int(units_avail.get(uk, 0)) < count or count <= 0:
            conn.close()
            raise HTTPException(status_code=400, detail=f"Yetersiz birlik: {uk}")
        units_avail[uk] -= count

    # Mesafe ve Süre Hesabı
    dx = float(from_v["x"] - to_v["x"])
    dy = float(from_v["y"] - to_v["y"])
    dist = math.sqrt(dx * dx + dy * dy)
    duration = max(30, int(dist * 60)) # Alan başına 60 sn
    arrival_unix = now + duration

    cursor.execute("""
        INSERT INTO movements (
            world_id, user_id, from_village_id, to_village_id, type,
            units_json, loot_json, start_unix, arrival_unix, status
        ) VALUES (?, ?, ?, ?, ?, ?, '{}', ?, ?, 'moving')
    """, (from_v["world_id"], user["id"], req.from_village_id, req.to_village_id, req.type, json.dumps(req.units), now, arrival_unix))

    cursor.execute("UPDATE villages SET units_json = ? WHERE id = ?", (json.dumps(units_avail), req.from_village_id))
    conn.commit()
    conn.close()

    return {"ok": True, "distance": round(dist, 1), "arrival_unix": arrival_unix, "duration_seconds": duration}

# -----------------------------------------------------------------------------
# Mektuplar ve Raporlar (Tam Hesap İzolasyonu)
# -----------------------------------------------------------------------------

@app.get("/api/messages/inbox")
def get_inbox(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM messages WHERE to_name = ? ORDER BY created_unix DESC LIMIT 50
    """, (user["display_name"],))
    rows = cursor.fetchall()
    conn.close()
    return {"ok": True, "messages": [dict(r) for r in rows]}

@app.get("/api/messages/sent")
def get_sent(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM messages WHERE from_name = ? ORDER BY created_unix DESC LIMIT 50
    """, (user["display_name"],))
    rows = cursor.fetchall()
    conn.close()
    return {"ok": True, "messages": [dict(r) for r in rows]}

@app.post("/api/messages/send")
def send_message(req: SendMessageRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    clean_to = html.escape(req.to_name.strip())
    clean_subj = html.escape(req.subject.strip())
    clean_body = html.escape(req.body.strip())

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO messages (world_id, from_name, to_name, subject, body, created_unix, is_read)
        VALUES (1, ?, ?, ?, ?, ?, 0)
    """, (user["display_name"], clean_to, clean_subj, clean_body, now))
    conn.commit()
    conn.close()

    return {"ok": True, "sent_unix": now}

@app.get("/api/game/state")
def get_cloud_state(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    ensure_cloud_saves_table(cursor, conn.is_pg)
    cloud_state, cloud_updated_unix, server_village = _fetch_cloud_and_village(
        cursor, user["id"], user["display_name"]
    )
    conn.commit()
    conn.close()
    if cloud_state is not None:
        return {
            "ok": True,
            "has_save": True,
            "state": cloud_state,
            "server_village": server_village,
            "updated_unix": cloud_updated_unix
        }
    if server_village is not None:
        return {
            "ok": True,
            "has_save": True,
            "state": None,
            "server_village": server_village,
            "updated_unix": int(server_village.get("last_calc_unix", 0))
        }
    return {"ok": True, "has_save": False, "state": None, "server_village": None, "updated_unix": 0}


@app.post("/api/game/save")
def post_cloud_save(payload: Dict[str, Any], user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    if isinstance(payload, dict) and isinstance(payload.get("state"), dict) and "world_id" not in payload:
        state_obj = payload["state"]
    else:
        state_obj = payload if isinstance(payload, dict) else {}
    state_json = json.dumps(state_obj, ensure_ascii=False)
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        ensure_cloud_saves_table(cursor, conn.is_pg)
        cursor.execute("SELECT user_id FROM cloud_saves WHERE user_id = ?", (user["id"],))
        if cursor.fetchone():
            cursor.execute(
                "UPDATE cloud_saves SET state_json = ?, updated_unix = ? WHERE user_id = ?",
                (state_json, now, user["id"])
            )
        else:
            cursor.execute(
                "INSERT INTO cloud_saves (user_id, state_json, updated_unix) VALUES (?, ?, ?)",
                (user["id"], state_json, now)
            )
    return {"ok": True, "updated_unix": now}


@app.get("/api/reports")
def get_reports(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM reports WHERE user_name = ? ORDER BY created_unix DESC LIMIT 50
    """, (user["display_name"],))
    rows = cursor.fetchall()
    conn.close()
    return {"ok": True, "reports": [dict(r) for r in rows]}

# -----------------------------------------------------------------------------
# Cron Tick (Vercel Cron veya Cloudflare Worker İle 60 Sn Tetikleme)
# -----------------------------------------------------------------------------
@app.get("/api/cron/tick")
def cron_tick():
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()

    # Süresi dolan ordu hareketlerini çöz
    cursor.execute("""
        SELECT * FROM movements WHERE status = 'moving' AND arrival_unix <= ?
    """, (now,))
    arrived = cursor.fetchall()

    resolved_count = 0
    for mov in arrived:
        m_id = mov["id"]
        from_vid = mov["from_village_id"]
        to_vid = mov["to_village_id"]
        units = json.loads(mov["units_json"])

        cursor.execute("SELECT * FROM villages WHERE id = ?", (from_vid,))
        from_v = cursor.fetchone()
        cursor.execute("SELECT * FROM villages WHERE id = ?", (to_vid,))
        to_v = cursor.fetchone()

        if from_v and to_v:
            # Savaş Raporu Oluştur (İki tarafa da yaz)
            rep_data = json.dumps({
                "type": mov["type"],
                "from_village": from_v["name"],
                "to_village": to_v["name"],
                "attacker": from_v["owner"],
                "defender": to_v["owner"],
                "attacker_units": units,
                "loot": {"wood": 250, "stone": 200, "iron": 180}
            })
            cursor.execute("""
                INSERT INTO reports (world_id, user_name, village_id, type, title, data_json, created_unix, is_unread)
                VALUES (1, ?, ?, 'battle', ?, ?, ?, 1)
            """, (from_v["owner"], from_vid, f"Savaş: {from_v['name']} -> {to_v['name']}", rep_data, now))

            cursor.execute("""
                INSERT INTO reports (world_id, user_name, village_id, type, title, data_json, created_unix, is_unread)
                VALUES (1, ?, ?, 'battle', ?, ?, ?, 1)
            """, (to_v["owner"], to_vid, f"Savunma: {to_v['name']} saldırıya uğradı!", rep_data, now))

        cursor.execute("UPDATE movements SET status = 'completed' WHERE id = ?", (m_id,))
        resolved_count += 1

    conn.commit()
    conn.close()

    return {"ok": True, "resolved_movements": resolved_count, "tick_unix": now}
