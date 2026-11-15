"""
Taht ve Kılıç (KingsAge 2) — Çevrimiçi Sunucu Motoru (Authoritative Serverless Engine)
Vercel Serverless ve Cloudflare ile uyumlu, SQL Injection Korumalı, 500+ Eşzamanlı Oyuncu Mimarisi.
"""

import os
import sys
import copy
import json
import time
import math
import html
import hashlib
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
            )""".format(bigint_t),

            """CREATE TABLE IF NOT EXISTS world_states (
                world_id INTEGER PRIMARY KEY,
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

            placed_bots = []
            for idx, bname in enumerate(bot_names, start=1):
                bx, by = 15, 15
                for _ in range(250):
                    cx = random.randint(15, 185)
                    cy = random.randint(15, 185)
                    if all(max(abs(cx - ox), abs(cy - oy)) >= 9 for ox, oy in placed_bots):
                        bx, by = cx, cy
                        break
                else:
                    bx = random.randint(15, 185)
                    by = random.randint(15, 185)
                placed_bots.append((bx, by))
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

STARTER_BOOST_SECONDS = 7 * 86400
STARTER_BOOST_MULTIPLIER = 2.0

def normalize_display_name(raw_name: str) -> str:
    n = re.sub(r"\s+", " ", (raw_name or "").strip())
    while len(n) >= 5 and n[:5].lower() == "lord " and len(n) > 5 and n[5:10].lower() == "lord ":
        n = n[5:].strip()
    if n.lower().startswith("lord "):
        n = "Lord " + n[5:].strip()
    elif n and not any(n.lower().startswith(p) for p in ("kral ", "baron ", "kont ", "dük ", "duk ", "prens ")):
        n = "Lord " + n
    return html.escape(n)

def get_starter_boost_until(conn: sqlite3.Connection, v_dict: Dict[str, Any], user_dict: Optional[Dict[str, Any]] = None) -> int:
    prot = int(v_dict.get("protection_until_unix", 0) or 0)
    v_created = (prot - 15 * 86400) if prot > (15 * 86400) else 0

    u_created = 0
    if user_dict and int(user_dict.get("created_unix", 0) or 0) > 0:
        u_created = int(user_dict["created_unix"])
    else:
        cursor = conn.cursor()
        uid = v_dict.get("user_id")
        owner = v_dict.get("owner")
        if uid:
            cursor.execute("SELECT created_unix FROM users WHERE id = ?", (uid,))
            row = cursor.fetchone()
            if row and int(row["created_unix"] or 0) > 0:
                u_created = int(row["created_unix"])
        if u_created <= 0 and owner:
            cursor.execute("SELECT created_unix FROM users WHERE LOWER(display_name) = LOWER(?)", (owner,))
            row = cursor.fetchone()
            if row and int(row["created_unix"] or 0) > 0:
                u_created = int(row["created_unix"])

    player_start = max(v_created, u_created)
    if player_start > 0:
        return player_start + STARTER_BOOST_SECONDS

    cursor = conn.cursor()
    wid = int(v_dict.get("world_id", 1))
    cursor.execute("SELECT created_unix FROM worlds WHERE id = ?", (wid,))
    wrow = cursor.fetchone()
    if wrow and int(wrow["created_unix"] or 0) > 0:
        return int(wrow["created_unix"]) + STARTER_BOOST_SECONDS
    return 0

def get_effective_speed(conn: sqlite3.Connection, v_dict: Dict[str, Any], now: int, user_dict: Optional[Dict[str, Any]] = None) -> float:
    boost_until = get_starter_boost_until(conn, v_dict, user_dict)
    if boost_until > 0 and now < boost_until:
        return STARTER_BOOST_MULTIPLIER
    return 1.0

def simulate_village_lazy(v_dict: Dict[str, Any], now: int, conn: sqlite3.Connection) -> Dict[str, Any]:
    """Sunucu taraflı lazy catch-up: maden üretimi ve tamamlanan kuyrukların işlenmesi."""
    last_calc = int(v_dict.get("last_calc_unix", now))
    elapsed = max(0, now - last_calc)

    blds = json.loads(v_dict["buildings_json"]) if isinstance(v_dict["buildings_json"], str) else v_dict["buildings_json"]
    res = json.loads(v_dict["resources_json"]) if isinstance(v_dict["resources_json"], str) else v_dict["resources_json"]
    units = json.loads(v_dict["units_json"]) if isinstance(v_dict["units_json"], str) else v_dict["units_json"]

    # 1. Maden Üretimi (İlk 7 gün 2x başlangıç hızı destekli)
    if elapsed > 0:
        boost_until = get_starter_boost_until(conn, v_dict)
        boosted_sec = 0
        if boost_until > last_calc:
            boosted_sec = max(0, min(now, boost_until) - last_calc)
        normal_sec = max(0, elapsed - boosted_sec)
        hours = (boosted_sec * STARTER_BOOST_MULTIPLIER + normal_sec) / 3600.0
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


MAX_REAL_PLAYERS_PER_WORLD = 100
WORLDS_COUNT = 10
MAP_SIZE = 200
MIN_VILLAGE_DISTANCE = 9


def _norm_p_name(raw_name: str) -> str:
    n = html.unescape(str(raw_name or "")).strip()
    n = re.sub(r"\s+", " ", n)
    while len(n) >= 10 and n[:10].lower() == "lord lord ":
        n = n[5:].strip()
    return n


def _matches_player(a: str, b: str) -> bool:
    na = _norm_p_name(a)
    nb = _norm_p_name(b)
    return bool(nb) and na.lower() == nb.lower()


def _is_real_player_village(v: Any) -> bool:
    if not isinstance(v, dict):
        return False
    owner = _norm_p_name(str(v.get("owner", "")))
    return (
        not bool(v.get("is_bot", False))
        and not bool(v.get("is_barbarian", False))
        and str(v.get("bonus_type", "")) == ""
        and owner.lower() not in ("", "barbar", "terk edilmiş", "terk edilmis", "soyguncular", "usta")
    )


def _is_spot_free_dist(occupied: set, x: int, y: int, min_dist: int = MIN_VILLAGE_DISTANCE, map_size: int = MAP_SIZE) -> bool:
    if x < 1 or x > map_size or y < 1 or y > map_size:
        return False
    if (x, y) in occupied:
        return False
    if min_dist <= 1:
        return True
    pad = min_dist - 1
    for ox, oy in occupied:
        if abs(x - ox) <= pad and abs(y - oy) <= pad:
            return False
    return True


def _find_free_spot_on_server(villages: List[Dict[str, Any]], pref_x: int = 100, pref_y: int = 100, min_dist: int = MIN_VILLAGE_DISTANCE, map_size: int = MAP_SIZE) -> tuple:
    occupied = {(int(v.get("x", 0)), int(v.get("y", 0))) for v in villages if isinstance(v, dict)}
    cx = max(1, min(map_size, int(pref_x)))
    cy = max(1, min(map_size, int(pref_y)))
    for d in (min_dist, 6, 4, 1):
        if _is_spot_free_dist(occupied, cx, cy, d, map_size):
            return (cx, cy)
        max_r = min(map_size, 80 if d > 1 else map_size)
        for radius in range(1, max_r + 1):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if max(abs(dx), abs(dy)) != radius:
                        continue
                    nx, ny = cx + dx, cy + dy
                    if _is_spot_free_dist(occupied, nx, ny, d, map_size):
                        return (nx, ny)
    for ny in range(1, map_size + 1):
        for nx in range(1, map_size + 1):
            if (nx, ny) not in occupied:
                return (nx, ny)
    return (cx, cy)


def _ensure_worlds_rows(cursor, now: int) -> None:
    for wid in range(1, WORLDS_COUNT + 1):
        cursor.execute("SELECT id FROM worlds WHERE id = ?", (wid,))
        if not cursor.fetchone():
            cursor.execute(
                """INSERT INTO worlds (id, name, seed, is_active, created_unix, registered_players)
                   VALUES (?, ?, ?, ?, ?, 0)""",
                (wid, f"Dünya {wid}", 1000 + wid, 1 if wid == 1 else 0, now)
            )


def _unwrap_world_payload(raw_w: Dict[str, Any], default_wid: int = 1, now: int = 0) -> Dict[str, Any]:
    if not isinstance(raw_w, dict):
        return {}
    if isinstance(raw_w.get("state"), dict):
        w = copy.deepcopy(raw_w)
        wid = int(w.get("world_id", w.get("id", default_wid)) or default_wid)
        w["world_id"] = wid
        w.setdefault("world_name", f"Dünya {wid}")
        w.setdefault("seed", 1000 + wid)
        w.setdefault("created_unix", now)
        w.setdefault("last_saved_unix", now)
        if not isinstance(w.get("registered_real_players"), list):
            w["registered_real_players"] = []
        return w
    wid = int(raw_w.get("world_id", raw_w.get("world", {}).get("world_id", default_wid)) or default_wid)
    return {
        "world_id": wid,
        "world_name": f"Dünya {wid}",
        "seed": 1000 + wid,
        "created_unix": now,
        "last_saved_unix": now,
        "registered_real_players": [],
        "state": copy.deepcopy(raw_w),
    }


def _collect_real_players(w_data: Dict[str, Any]) -> List[str]:
    seen = {}
    out: List[str] = []
    for name in (w_data.get("registered_real_players") or []):
        n = _norm_p_name(str(name))
        if n and n.lower() not in seen:
            seen[n.lower()] = True
            out.append(n)
    state = w_data.get("state") or {}
    for v in (state.get("villages") or []):
        if _is_real_player_village(v):
            n = _norm_p_name(str(v.get("owner", "")))
            if n and n.lower() not in seen:
                seen[n.lower()] = True
                out.append(n)
    return out


def _player_has_village_in_world(w_data: Optional[Dict[str, Any]], player_name: str) -> bool:
    if not isinstance(w_data, dict):
        return False
    state = w_data.get("state") or {}
    for v in (state.get("villages") or []):
        if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), player_name):
            return True
    return False


def _prepare_world_for_player(world_w: Optional[Dict[str, Any]], player_name: str) -> Optional[Dict[str, Any]]:
    if not isinstance(world_w, dict):
        return None
    w = copy.deepcopy(world_w)
    state = w.setdefault("state", {})
    w_dict = state.setdefault("world", {})
    norm_p = _norm_p_name(player_name)

    profiles = w_dict.get("player_profiles")
    if not isinstance(profiles, dict):
        profiles = {}
        w_dict["player_profiles"] = profiles

    found_prof: Dict[str, Any] = {}
    for pk, pv in profiles.items():
        if _matches_player(pk, norm_p) and isinstance(pv, dict):
            found_prof = copy.deepcopy(pv)
            break

    psb = w_dict.get("player_starter_boost")
    if not isinstance(psb, dict):
        psb = {}
        w_dict["player_starter_boost"] = psb
    boost_rec: Dict[str, Any] = {}
    for bk, bv in psb.items():
        if _matches_player(bk, norm_p) and isinstance(bv, dict):
            boost_rec = bv
            break

    villages = state.get("villages") or []
    first_vid = -1
    owned_vids: List[int] = []
    total_points = 0
    for v in villages:
        if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), norm_p):
            vid = int(v.get("id", -1))
            if first_vid < 0:
                first_vid = vid
            owned_vids.append(vid)
            total_points += int(v.get("points", 110))

    prof_active = int(found_prof.get("active_village_id", -1) or -1)
    if prof_active in owned_vids:
        active_vid = prof_active
    elif first_vid > 0:
        active_vid = first_vid
    else:
        active_vid = -1

    q_dict = found_prof.get("quests")
    if not isinstance(q_dict, dict):
        q_dict = {"claimed": [], "stats": {}}

    created_u = int(found_prof.get("created_unix", boost_rec.get("created_unix", 0)) or 0)
    boost_u = int(found_prof.get("starter_boost_until_unix", boost_rec.get("starter_boost_until_unix", 0)) or 0)
    if boost_u <= 0 and created_u > 0:
        boost_u = created_u + STARTER_BOOST_SECONDS

    state["active_village_id"] = active_vid
    state["player"] = {
        "id": 1,
        "name": norm_p or str(player_name),
        "auth_id": str(found_prof.get("auth_id", "")),
        "provider": str(found_prof.get("provider", "")),
        "points": total_points,
        "created_unix": created_u,
        "starter_boost_until_unix": boost_u,
        "protection_until_unix": int(found_prof.get("protection_until_unix", 0) or 0),
        "conquest_protection_until_unix": int(found_prof.get("conquest_protection_until_unix", 0) or 0),
        "tutorial_completed": bool(found_prof.get("tutorial_completed", False)),
        "tutorial_step": int(found_prof.get("tutorial_step", 0) or 0),
        "tutorial_reward_claimed": bool(found_prof.get("tutorial_reward_claimed", False)),
        "quests": copy.deepcopy(q_dict),
        "gold_armour": int(found_prof.get("gold_armour", 0) or 0),
        "premium": False,
    }
    w["registered_real_players"] = _collect_real_players(w)
    return w


def _rebuild_tiles(state: Dict[str, Any]) -> None:
    w_dict = state.setdefault("world", {})
    tiles: Dict[str, int] = {}
    for v in (state.get("villages") or []):
        if isinstance(v, dict):
            tiles[f"{int(v.get('x', 1))},{int(v.get('y', 1))}"] = int(v.get("id", 0))
    w_dict["tiles"] = tiles
    w_dict["villages"] = state.get("villages") or []


def _report_sig(rep: Any) -> tuple:
    if not isinstance(rep, dict):
        return ("",)
    data = rep.get("data") if isinstance(rep.get("data"), dict) else {}
    return (
        str(rep.get("type", "")),
        int(rep.get("village_id", 0) or 0),
        int(rep.get("unix", rep.get("created_unix", 0)) or 0),
        int(data.get("target_village_id", 0) or 0),
        int(data.get("from_village_id", 0) or 0),
    )


def _message_sig(msg: Any) -> tuple:
    if not isinstance(msg, dict):
        return ("",)
    return (
        str(msg.get("from", msg.get("from_name", ""))).strip(),
        str(msg.get("to", msg.get("to_name", ""))).strip(),
        str(msg.get("subject", "")).strip(),
        int(msg.get("created_unix", 0) or 0),
    )


def _movement_sig(mov: Any) -> tuple:
    if not isinstance(mov, dict):
        return ("",)
    return (
        int(mov.get("from_village_id", mov.get("village_id", 0)) or 0),
        int(mov.get("to_village_id", 0) or 0),
        str(mov.get("type", "")),
        int(mov.get("depart_unix", mov.get("start_unix", 0)) or 0),
        int(mov.get("arrive_unix", mov.get("arrival_unix", 0)) or 0),
    )


def merge_world_state(server_w: Optional[Dict[str, Any]], client_raw: Dict[str, Any], acting_player: str, now: int) -> Dict[str, Any]:
    """Birden fazla oyuncunun aynı ortak dünyadaki hamlelerini güvenli şekilde birleştirir."""
    act_name = _norm_p_name(acting_player)
    c_w = _unwrap_world_payload(client_raw, int((server_w or {}).get("world_id", 1) or 1), now)
    c_state = c_w.setdefault("state", {})
    c_w_dict = c_state.setdefault("world", {})

    # Güncel oyuncu profilini client'ın state.player'ından player_profiles içine yansıt
    c_player = c_state.get("player")
    if isinstance(c_player, dict) and act_name:
        c_profs = c_w_dict.setdefault("player_profiles", {})
        c_profs[act_name] = {
            "name": act_name,
            "provider": str(c_player.get("provider", "")),
            "auth_id": str(c_player.get("auth_id", "")),
            "points": int(c_player.get("points", 0) or 0),
            "created_unix": int(c_player.get("created_unix", 0) or 0),
            "starter_boost_until_unix": int(c_player.get("starter_boost_until_unix", 0) or 0),
            "protection_until_unix": int(c_player.get("protection_until_unix", 0) or 0),
            "conquest_protection_until_unix": int(c_player.get("conquest_protection_until_unix", 0) or 0),
            "tutorial_completed": bool(c_player.get("tutorial_completed", False)),
            "tutorial_step": int(c_player.get("tutorial_step", 0) or 0),
            "tutorial_reward_claimed": bool(c_player.get("tutorial_reward_claimed", False)),
            "quests": copy.deepcopy(c_player.get("quests") if isinstance(c_player.get("quests"), dict) else {"claimed": [], "stats": {}}),
            "gold_armour": int(c_player.get("gold_armour", 0) or 0),
            "active_village_id": int(c_state.get("active_village_id", -1) or -1),
        }

    if not server_w or not isinstance(server_w.get("state"), dict) or not (server_w["state"].get("villages")):
        merged = copy.deepcopy(c_w)
        merged["last_saved_unix"] = now
        merged["registered_real_players"] = _collect_real_players(merged)
        _rebuild_tiles(merged["state"])
        return merged

    merged = copy.deepcopy(server_w)
    s_state = merged.setdefault("state", {})
    s_w_dict = s_state.setdefault("world", {})
    s_last = int(merged.get("last_saved_unix", 0) or 0)
    c_last = int(c_w.get("last_saved_unix", now) or now)

    # 1. Profiller ve başlangıç bonusları (her oyuncunun verisi ayrı korunur)
    s_profs = s_w_dict.setdefault("player_profiles", {})
    c_profs = c_w_dict.get("player_profiles") if isinstance(c_w_dict.get("player_profiles"), dict) else {}
    for pk, pv in c_profs.items():
        if isinstance(pv, dict) and (_matches_player(pk, act_name) or pk not in s_profs):
            s_profs[pk] = copy.deepcopy(pv)

    s_psb = s_w_dict.setdefault("player_starter_boost", {})
    c_psb = c_w_dict.get("player_starter_boost") if isinstance(c_w_dict.get("player_starter_boost"), dict) else {}
    for bk, bv in c_psb.items():
        if isinstance(bv, dict) and (_matches_player(bk, act_name) or bk not in s_psb):
            s_psb[bk] = copy.deepcopy(bv)

    # 2. Köyleri indeksle ve eşzamanlı yeni köy ID / mesafe çakışmalarını çöz
    s_villages: List[Dict[str, Any]] = [copy.deepcopy(v) for v in (s_state.get("villages") or []) if isinstance(v, dict)]
    c_villages: List[Dict[str, Any]] = [copy.deepcopy(v) for v in (c_state.get("villages") or []) if isinstance(v, dict)]

    s_by_id: Dict[int, Dict[str, Any]] = {int(v.get("id", 0)): v for v in s_villages}
    c_by_id: Dict[int, Dict[str, Any]] = {int(v.get("id", 0)): v for v in c_villages}
    max_vid = max(list(s_by_id.keys()) + list(c_by_id.keys()) + [106])

    # Client ve server raporlarından yeni savaş / fetih raporlarını topla
    s_report_sigs = {_report_sig(r) for r in (s_state.get("reports") or [])}
    c_report_sigs = {_report_sig(r) for r in (c_state.get("reports") or []) if isinstance(r, dict)}
    new_client_reports: List[Dict[str, Any]] = []
    all_conquered_target_vids = set()
    server_conquered_vids = set()
    unseen_server_battles_by_vid: Dict[int, List[Dict[str, Any]]] = {}
    for rep in (s_state.get("reports") or []):
        if isinstance(rep, dict) and rep.get("type") == "battle":
            rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
            t_vid = int(rdata.get("target_village_id", 0) or 0)
            if bool(rdata.get("conquered", False)):
                all_conquered_target_vids.add(t_vid)
                server_conquered_vids.add(t_vid)
            if _report_sig(rep) not in c_report_sigs and t_vid > 0:
                unseen_server_battles_by_vid.setdefault(t_vid, []).append(rep)
    for rep in (c_state.get("reports") or []):
        if isinstance(rep, dict):
            rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
            if rep.get("type") == "battle" and bool(rdata.get("conquered", False)):
                all_conquered_target_vids.add(int(rdata.get("target_village_id", 0) or 0))
            if _report_sig(rep) not in s_report_sigs:
                new_client_reports.append(rep)

    vid_remap: Dict[int, int] = {}
    stale_conquered_vids = set()
    acting_client_vids_before = {
        int(v.get("id", 0)) for v in c_villages
        if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), act_name)
    }

    # Client'taki aktif oyuncunun köylerini kontrol et: başka bir gerçek oyuncunun köy ID'siyle çakışıyor mu veya < 9 mesafede mi?
    for c_v in c_villages:
        if not (_is_real_player_village(c_v) and _matches_player(str(c_v.get("owner", "")), act_name)):
            continue
        old_vid = int(c_v.get("id", 0))
        s_match = s_by_id.get(old_vid)
        is_new_starter_or_collision = False
        if s_match is not None and _is_real_player_village(s_match) and not _matches_player(str(s_match.get("owner", "")), act_name):
            same_xy = (int(c_v.get("x", -1)) == int(s_match.get("x", -2)) and int(c_v.get("y", -1)) == int(s_match.get("y", -2)))
            if same_xy and old_vid in server_conquered_vids:
                # Bu köy başka bir oyuncu tarafından zaten fethedilmiş; eski sahibin bayat kaydı klon oluşturmamalı!
                stale_conquered_vids.add(old_vid)
                continue
            if not (same_xy and old_vid in all_conquered_target_vids):
                is_new_starter_or_collision = True
                max_vid += 1
                vid_remap[old_vid] = max_vid
                c_v["id"] = max_vid
                old_vid = max_vid
        elif s_match is None:
            is_new_starter_or_collision = True

        if is_new_starter_or_collision:
            occupied = {(int(v.get("x", 0)), int(v.get("y", 0))) for v in s_villages}
            vx, vy = int(c_v.get("x", 100)), int(c_v.get("y", 100))
            if not _is_spot_free_dist(occupied, vx, vy, MIN_VILLAGE_DISTANCE, MAP_SIZE):
                nx, ny = _find_free_spot_on_server(s_villages, vx, vy, MIN_VILLAGE_DISTANCE, MAP_SIZE)
                c_v["x"] = nx
                c_v["y"] = ny
            s_villages.append(c_v)

    # Remap edilmiş ID'yi profildeki active_village_id içine de uygula
    if act_name in s_profs and isinstance(s_profs[act_name], dict):
        av = int(s_profs[act_name].get("active_village_id", -1) or -1)
        if av in stale_conquered_vids:
            s_profs[act_name]["active_village_id"] = -1
        elif av in vid_remap:
            s_profs[act_name]["active_village_id"] = vid_remap[av]

    # Remap sonrası client köylerini birleştir
    for c_v in c_villages:
        vid = int(c_v.get("id", 0))
        if vid in stale_conquered_vids:
            continue
        is_act_v = _is_real_player_village(c_v) and _matches_player(str(c_v.get("owner", "")), act_name)
        s_v = s_by_id.get(vid)

        if is_act_v:
            # Aktif oyuncunun kendi köyü (veya fethettiği köy): henüz client'ın görmediği sunucu savaşlarını koru
            if vid in unseen_server_battles_by_vid:
                v_units = dict(c_v.get("units") or {})
                v_res = dict(c_v.get("resources") or {})
                for urep in unseen_server_battles_by_vid[vid]:
                    urdata = urep.get("data") if isinstance(urep.get("data"), dict) else {}
                    for uk, loss in (urdata.get("defender_losses") or {}).items():
                        v_units[uk] = max(0, int(v_units.get(uk, 0) or 0) - int(loss or 0))
                    for rk, loot_v in (urdata.get("loot") or {}).items():
                        v_res[rk] = max(0, int(v_res.get(rk, 0) or 0) - int(loot_v or 0))
                    if "realm_after" in urdata and int(urdata.get("realm_after", -1)) >= 0:
                        c_v["realm_of_power"] = int(urdata["realm_after"])
                c_v["units"] = v_units
                c_v["resources"] = v_res
            s_by_id[vid] = c_v
            continue

        if s_v is None:
            s_by_id[vid] = c_v
            continue

        if _is_real_player_village(s_v):
            # Başka gerçek bir oyuncunun köyü! Kendi binalarını/kuyruklarını koru, sadece yeni destek/savaş farkını uygula
            s_sup = list(s_v.get("support") or []) if isinstance(s_v.get("support"), list) else []
            c_sup = list(c_v.get("support") or []) if isinstance(c_v.get("support"), list) else []

            def _sup_key(item):
                if not isinstance(item, dict):
                    return ("",)
                return (
                    int(item.get("from_village_id", 0) or 0),
                    int(item.get("arrive_unix", 0) or 0),
                )

            s_act_sups = {_sup_key(it): it for it in s_sup if isinstance(it, dict) and (int(it.get("from_village_id", 0) or 0) in acting_client_vids_before or _matches_player(str(it.get("owner", "")), act_name))}
            c_act_sups = {_sup_key(it): it for it in c_sup if isinstance(it, dict) and (int(it.get("from_village_id", 0) or 0) in acting_client_vids_before or _matches_player(str(it.get("owner", "")), act_name))}

            # Aktif oyuncudan yeni gelen destekleri ekle, geri çekilenleri düş
            v_units = dict(s_v.get("units") or {})
            kept_sups = [it for it in s_sup if _sup_key(it) not in s_act_sups or _sup_key(it) in c_act_sups]
            for sk, sit in s_act_sups.items():
                if sk not in c_act_sups:
                    for uk, cnt in (sit.get("units") or {}).items():
                        v_units[uk] = max(0, int(v_units.get(uk, 0) or 0) - int(cnt or 0))
            for ck, cit in c_act_sups.items():
                if ck not in s_act_sups:
                    cit_copy = copy.deepcopy(cit)
                    fv = int(cit_copy.get("from_village_id", 0) or 0)
                    if fv in vid_remap:
                        cit_copy["from_village_id"] = vid_remap[fv]
                    kept_sups.append(cit_copy)
                    for uk, cnt in (cit_copy.get("units") or {}).items():
                        v_units[uk] = int(v_units.get(uk, 0) or 0) + int(cnt or 0)
            s_v["support"] = kept_sups
            s_v["units"] = v_units

            # Aktif oyuncunun bu köye yönelik YENİ savaş raporu varsa kayıpları/yağmayı/sur hasarını uygula
            for rep in new_client_reports:
                if rep.get("type") == "battle":
                    rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
                    if int(rdata.get("target_village_id", 0) or 0) == vid:
                        for uk, loss in (rdata.get("defender_losses") or {}).items():
                            v_units[uk] = max(0, int(v_units.get(uk, 0) or 0) - int(loss or 0))
                        s_v["units"] = v_units
                        v_res = dict(s_v.get("resources") or {})
                        for rk, loot_v in (rdata.get("loot") or {}).items():
                            v_res[rk] = max(0, int(v_res.get(rk, 0) or 0) - int(loot_v or 0))
                        s_v["resources"] = v_res
                        if "realm_after" in rdata and int(rdata.get("realm_after", -1)) >= 0:
                            s_v["realm_of_power"] = int(rdata["realm_after"])
            continue

        # Bot / Barbar / Bonus köyü: savaş raporu veya daha güncel simülasyon verisi varsa al
        has_new_battle = any(
            rep.get("type") == "battle" and int((rep.get("data") or {}).get("target_village_id", 0) or 0) == vid
            for rep in new_client_reports
        )
        if has_new_battle or c_last >= s_last or int(c_v.get("points", 0) or 0) > int(s_v.get("points", 0) or 0):
            s_by_id[vid] = c_v

    s_state["villages"] = sorted(s_by_id.values(), key=lambda v: int(v.get("id", 0)))
    _rebuild_tiles(s_state)

    acting_vids_now = {
        int(v.get("id", 0)) for v in s_state["villages"]
        if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), act_name)
    }

    # 3. Kuyruklar (queues): aktif oyuncunun köylerinin kuyruğu client'tan, diğerlerininki server'dan
    merged_queues: List[Dict[str, Any]] = []
    for q in (s_state.get("queues") or []):
        if isinstance(q, dict) and int(q.get("village_id", 0) or 0) not in acting_vids_now:
            merged_queues.append(q)
    for q in (c_state.get("queues") or []):
        if isinstance(q, dict):
            qc = copy.deepcopy(q)
            q_vid = int(qc.get("village_id", 0) or 0)
            if q_vid in vid_remap:
                q_vid = vid_remap[q_vid]
                qc["village_id"] = q_vid
            if q_vid in acting_vids_now:
                merged_queues.append(qc)
    s_state["queues"] = merged_queues

    # 4. Hareketler (movements)
    merged_movements: List[Dict[str, Any]] = []
    seen_mov = set()
    # Önce aktif oyuncunun köylerinden çıkan/client'ta bilinen hareketler
    for m in (c_state.get("movements") or []):
        if not isinstance(m, dict):
            continue
        mc = copy.deepcopy(m)
        fv = int(mc.get("from_village_id", mc.get("village_id", 0)) or 0)
        tv = int(mc.get("to_village_id", 0) or 0)
        if fv in vid_remap:
            mc["from_village_id"] = vid_remap[fv]
            if "village_id" in mc:
                mc["village_id"] = vid_remap[fv]
        if tv in vid_remap:
            mc["to_village_id"] = vid_remap[tv]
        sig = _movement_sig(mc)
        if sig not in seen_mov:
            seen_mov.add(sig)
            merged_movements.append(mc)
    # Diğer gerçek oyuncuların sunucudaki hareketlerini koru (henüz varmamış olanları)
    for m in (s_state.get("movements") or []):
        if not isinstance(m, dict):
            continue
        fv = int(m.get("from_village_id", m.get("village_id", 0)) or 0)
        if fv in acting_vids_now or fv in acting_client_vids_before:
            continue  # Aktif oyuncunun kendi hareketlerinde client otoriterdir
        sig = _movement_sig(m)
        if sig not in seen_mov and (int(m.get("arrive_unix", 0) or 0) > now or int(m.get("to_village_id", 0) or 0) not in acting_vids_now):
            seen_mov.add(sig)
            merged_movements.append(m)
    s_state["movements"] = merged_movements

    # 5. İttifaklar (alliances)
    s_alliances = {str(a.get("name", "")).strip().lower(): copy.deepcopy(a) for a in (s_state.get("alliances") or []) if isinstance(a, dict)}
    max_aid = max([int(a.get("id", 0) or 0) for a in s_alliances.values()] + [0])

    # Aktif oyuncu client'ta hangi ittifaka üye?
    act_c_alliance_key = ""
    for a in (c_state.get("alliances") or []):
        if not isinstance(a, dict):
            continue
        for m in (a.get("members") or []):
            if isinstance(m, dict) and _matches_player(str(m.get("name", "")), act_name):
                act_c_alliance_key = str(a.get("name", "")).strip().lower()
                break

    for c_a in (c_state.get("alliances") or []):
        if not isinstance(c_a, dict):
            continue
        akey = str(c_a.get("name", "")).strip().lower()
        if not akey:
            continue
        if akey not in s_alliances:
            ac = copy.deepcopy(c_a)
            aid = int(ac.get("id", 0) or 0)
            if aid <= 0 or any(int(sa.get("id", 0) or 0) == aid for sa in s_alliances.values()):
                max_aid += 1
                ac["id"] = max_aid
            s_alliances[akey] = ac
            continue

        sa = s_alliances[akey]
        # Sohbet mesajlarını birleştir
        s_chat = list(sa.get("chat_messages") or [])
        c_chat = list(c_a.get("chat_messages") or [])
        seen_chat = {(str(cm.get("sender", "")), str(cm.get("text", "")), int(cm.get("timestamp_unix", 0) or 0)) for cm in s_chat if isinstance(cm, dict)}
        for cm in c_chat:
            if isinstance(cm, dict):
                csig = (str(cm.get("sender", "")), str(cm.get("text", "")), int(cm.get("timestamp_unix", 0) or 0))
                if csig not in seen_chat:
                    seen_chat.add(csig)
                    s_chat.append(copy.deepcopy(cm))
        s_chat.sort(key=lambda x: int(x.get("timestamp_unix", 0) or 0))
        sa["chat_messages"] = s_chat[-150:]

        # Üyeleri birleştir (diğer oyuncuları koru, aktif oyuncunun katılma/ayrılmasını işle)
        s_mems = {str(m.get("name", "")).strip().lower(): copy.deepcopy(m) for m in (sa.get("members") or []) if isinstance(m, dict)}
        c_mems = {str(m.get("name", "")).strip().lower(): copy.deepcopy(m) for m in (c_a.get("members") or []) if isinstance(m, dict)}
        if act_c_alliance_key == akey and act_name.lower() in c_mems:
            s_mems[act_name.lower()] = c_mems[act_name.lower()]
        elif act_name.lower() in s_mems and act_name.lower() not in c_mems:
            s_mems.pop(act_name.lower(), None)
        for mk, mv in c_mems.items():
            if mk not in s_mems and int(mv.get("joined_unix", 0) or 0) >= s_last - 10:
                s_mems[mk] = mv
        sa["members"] = list(s_mems.values())

        # Davetleri birleştir
        s_invs = {str(i.get("player_name", "")).strip().lower(): copy.deepcopy(i) for i in (sa.get("invitations") or []) if isinstance(i, dict)}
        c_invs = {str(i.get("player_name", "")).strip().lower(): copy.deepcopy(i) for i in (c_a.get("invitations") or []) if isinstance(i, dict)}
        for ik, iv in c_invs.items():
            if ik not in s_invs and int(iv.get("created_unix", 0) or 0) >= s_last - 10:
                s_invs[ik] = iv
        if act_name.lower() in s_invs and act_name.lower() not in c_invs:
            s_invs.pop(act_name.lower(), None)
        for mk in list(s_invs.keys()):
            if mk in s_mems:
                s_invs.pop(mk, None)
        sa["invitations"] = list(s_invs.values())

        # Diplomasi / açıklama / lider (eğer aktif oyuncu liderse veya son değişiklik yaptıysa)
        if _matches_player(str(sa.get("leader", "")), act_name):
            if isinstance(c_a.get("diplomacy"), dict):
                sa["diplomacy"] = copy.deepcopy(c_a["diplomacy"])
            if "description" in c_a:
                sa["description"] = c_a["description"]
            if "internal_announcement" in c_a:
                sa["internal_announcement"] = c_a["internal_announcement"]

    s_state["alliances"] = list(s_alliances.values())

    # 6. Mesajlar ve Raporlar (deduplicated union)
    s_msgs = list(s_state.get("messages") or [])
    msg_idx = {_message_sig(m): i for i, m in enumerate(s_msgs) if isinstance(m, dict)}
    for m in (c_state.get("messages") or []):
        if not isinstance(m, dict):
            continue
        msig = _message_sig(m)
        if msig not in msg_idx:
            msg_idx[msig] = len(s_msgs)
            s_msgs.append(copy.deepcopy(m))
        elif _matches_player(str(m.get("to", m.get("to_name", ""))), act_name) and bool(m.get("read", False)):
            s_msgs[msg_idx[msig]]["read"] = True
    s_state["messages"] = s_msgs[-250:]

    s_reps = list(s_state.get("reports") or [])
    seen_reps = {_report_sig(r) for r in s_reps if isinstance(r, dict)}
    for r in (c_state.get("reports") or []):
        if not isinstance(r, dict):
            continue
        rc = copy.deepcopy(r)
        rv = int(rc.get("village_id", 0) or 0)
        if rv in vid_remap:
            rc["village_id"] = vid_remap[rv]
        if isinstance(rc.get("data"), dict):
            fv = int(rc["data"].get("from_village_id", 0) or 0)
            if fv in vid_remap:
                rc["data"]["from_village_id"] = vid_remap[fv]
        rsig = _report_sig(rc)
        if rsig not in seen_reps:
            seen_reps.add(rsig)
            s_reps.append(rc)
    s_state["reports"] = s_reps[-250:]

    # 7. Dünya meta & kayıtlı oyuncular
    merged["last_saved_unix"] = now
    s_w_dict["last_saved_unix"] = now
    s_w_dict["sim_now_unix"] = max(int(s_w_dict.get("sim_now_unix", 0) or 0), int(c_w_dict.get("sim_now_unix", now) or now), now)
    merged["registered_real_players"] = _collect_real_players(merged)
    return merged


def ensure_cloud_saves_table(cursor, is_pg: bool) -> None:
    bigint_t = "BIGINT" if is_pg else "INTEGER"
    cursor.execute("""CREATE TABLE IF NOT EXISTS cloud_saves (
        user_id TEXT PRIMARY KEY,
        state_json TEXT NOT NULL,
        updated_unix {0} NOT NULL
    )""".format(bigint_t))
    cursor.execute("""CREATE TABLE IF NOT EXISTS world_states (
        world_id INTEGER PRIMARY KEY,
        state_json TEXT NOT NULL,
        updated_unix {0} NOT NULL
    )""".format(bigint_t))


def _sync_worlds_table_from_states(cursor, now: int) -> List[Dict[str, Any]]:
    _ensure_worlds_rows(cursor, now)
    cursor.execute("SELECT world_id, state_json FROM world_states ORDER BY world_id ASC")
    ws_rows = cursor.fetchall()
    reg_counts: Dict[int, int] = {}
    for row in ws_rows:
        wid = int(row["world_id"])
        try:
            w_data = json.loads(row["state_json"])
            reg_counts[wid] = len(_collect_real_players(w_data))
        except Exception:
            reg_counts[wid] = 0

    for wid in range(1, WORLDS_COUNT + 1):
        cnt = reg_counts.get(wid, None)
        if cnt is not None:
            cursor.execute("UPDATE worlds SET registered_players = ? WHERE id = ?", (cnt, wid))
            if cnt >= MAX_REAL_PLAYERS_PER_WORLD and wid < WORLDS_COUNT:
                cursor.execute("UPDATE worlds SET is_active = 1 WHERE id = ?", (wid + 1,))

    cursor.execute("SELECT * FROM worlds ORDER BY id ASC")
    rows = cursor.fetchall()
    out: List[Dict[str, Any]] = []
    for r in rows:
        d = dict(r)
        wid = int(d["id"])
        if wid in reg_counts:
            d["registered_players"] = reg_counts[wid]
        out.append(d)
    return out


def _migrate_legacy_cloud_saves_to_world_states(cursor, now: int) -> None:
    cursor.execute("SELECT COUNT(*) as cnt FROM world_states")
    c_row = cursor.fetchone()
    if c_row and int(list(c_row.values())[0] or 0) > 0:
        return
    cursor.execute("SELECT cs.user_id, cs.state_json, cs.updated_unix, u.display_name FROM cloud_saves cs LEFT JOIN users u ON u.id = cs.user_id ORDER BY cs.updated_unix ASC")
    legacy_rows = cursor.fetchall()
    for row in legacy_rows:
        try:
            raw = json.loads(row["state_json"])
        except Exception:
            continue
        w_id = int(raw.get("world_id", raw.get("state", {}).get("world", {}).get("world_id", 1)) or 1)
        cursor.execute("SELECT state_json FROM world_states WHERE world_id = ?", (w_id,))
        existing_ws = cursor.fetchone()
        server_w = json.loads(existing_ws["state_json"]) if existing_ws else None
        p_name = str(row.get("display_name") or raw.get("state", {}).get("player", {}).get("name", "") or "Lord Gorkem")
        merged = merge_world_state(server_w, raw, p_name, int(row["updated_unix"] or now))
        merged_json = json.dumps(merged, ensure_ascii=False)
        if existing_ws:
            cursor.execute("UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?", (merged_json, int(row["updated_unix"] or now), w_id))
        else:
            cursor.execute("INSERT INTO world_states (world_id, state_json, updated_unix) VALUES (?, ?, ?)", (w_id, merged_json, int(row["updated_unix"] or now)))


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
    now = int(time.time())
    _migrate_legacy_cloud_saves_to_world_states(cursor, now)
    worlds_meta = _sync_worlds_table_from_states(cursor, now)

    cursor.execute("SELECT world_id, state_json, updated_unix FROM world_states ORDER BY world_id ASC")
    ws_rows = cursor.fetchall()

    chosen_w = None
    chosen_updated = 0
    # 1. Öncelik: Bu oyuncunun köyünün bulunduğu ortak dünya
    for row in ws_rows:
        try:
            w_data = json.loads(row["state_json"])
        except Exception:
            continue
        if _player_has_village_in_world(w_data, display_name) or any(_matches_player(n, display_name) for n in _collect_real_players(w_data)):
            chosen_w = w_data
            chosen_updated = int(row["updated_unix"] or 0)
            break

    # 2. Öncelik: Yeni oyuncu ise aktif ve henüz 100 oyuncuya ulaşmamış ilk ortak dünya
    if chosen_w is None:
        active_ids = {int(wm["id"]) for wm in worlds_meta if int(wm.get("is_active", 0)) == 1}
        for row in ws_rows:
            wid = int(row["world_id"])
            if wid not in active_ids:
                continue
            try:
                w_data = json.loads(row["state_json"])
            except Exception:
                continue
            if len(_collect_real_players(w_data)) < MAX_REAL_PLAYERS_PER_WORLD:
                chosen_w = w_data
                chosen_updated = int(row["updated_unix"] or 0)
                break

    # 3. Fallback: İlk mevcut world_states kaydı
    if chosen_w is None and ws_rows:
        try:
            chosen_w = json.loads(ws_rows[0]["state_json"])
            chosen_updated = int(ws_rows[0]["updated_unix"] or 0)
        except Exception:
            chosen_w = None

    cloud_state = _prepare_world_for_player(chosen_w, display_name) if chosen_w is not None else None
    if cloud_state is None:
        cursor.execute("SELECT state_json, updated_unix FROM cloud_saves WHERE user_id = ?", (user_id,))
        c_row = cursor.fetchone()
        if c_row:
            chosen_updated = int(c_row["updated_unix"])
            try:
                cloud_state = json.loads(c_row["state_json"])
            except Exception:
                cloud_state = None

    cursor.execute("SELECT * FROM villages WHERE owner = ? AND is_bot = 0 ORDER BY id ASC LIMIT 1", (display_name,))
    v_row = cursor.fetchone()
    server_village = _serialize_server_village(v_row)
    return cloud_state, chosen_updated, server_village


@app.post("/api/auth/login")
def auth_login(req: AuthLoginRequest):
    display_name = normalize_display_name(req.display_name)
    if not display_name:
        raise HTTPException(status_code=400, detail="Geçersiz kullanıcı adı.")

    now = int(time.time())
    provider = (req.provider or "google").strip().lower()
    if provider not in ("google", "apple"):
        provider = "google"

    det_hash = hashlib.sha256(f"{provider}:{display_name.lower()}".encode("utf-8")).hexdigest()[:12]
    user_id = f"{provider}_{det_hash}"
    token = f"tk_tok_{secrets.token_hex(24)}"
    email = req.email or f"{display_name.lower().replace(' ', '.')}@{provider}.com"

    conn = get_db()
    cursor = conn.cursor()
    ensure_cloud_saves_table(cursor, conn.is_pg)

    bare_name = display_name[5:].strip() if display_name.startswith("Lord ") else display_name
    candidates = [display_name]
    if bare_name and bare_name != display_name:
        candidates.append(bare_name)

    existing = None
    for cand in candidates:
        cursor.execute("SELECT * FROM users WHERE LOWER(display_name) = LOWER(?) AND provider = ?", (cand, provider))
        existing = cursor.fetchone()
        if existing:
            break
    if not existing:
        for cand in candidates:
            cursor.execute("SELECT * FROM users WHERE LOWER(display_name) = LOWER(?)", (cand,))
            existing = cursor.fetchone()
            if existing:
                break

    created_unix = now
    if existing:
        user_id = existing["id"]
        display_name = existing["display_name"]
        created_unix = int(existing["created_unix"] or now)
        cursor.execute("UPDATE users SET token = ?, last_login_unix = ?, provider = ? WHERE id = ?", (token, now, provider, user_id))
    else:
        cursor.execute("""
            INSERT INTO users (id, provider, email, display_name, token, created_unix, last_login_unix)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, provider, email, display_name, token, now, now))

    cloud_state, cloud_updated_unix, server_village = _fetch_cloud_and_village(cursor, user_id, display_name)
    worlds_meta = _sync_worlds_table_from_states(cursor, now)
    has_village = bool(server_village is not None or _player_has_village_in_world(cloud_state, display_name))

    conn.commit()
    conn.close()

    return {
        "ok": True,
        "token": token,
        "user_id": user_id,
        "provider": provider,
        "display_name": display_name,
        "created_unix": created_unix,
        "starter_boost_until_unix": created_unix + STARTER_BOOST_SECONDS,
        "has_village": has_village,
        "cloud_state": cloud_state,
        "worlds_meta": worlds_meta,
        "updated_unix": cloud_updated_unix,
        "server_village": server_village
    }

@app.get("/api/auth/me")
def get_me(user: Dict[str, Any] = Depends(get_current_user)):
    return {"ok": True, "user": user}

@app.get("/api/worlds")
def get_worlds():
    now = int(time.time())
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _migrate_legacy_cloud_saves_to_world_states(cursor, now)
        worlds = _sync_worlds_table_from_states(cursor, now)
    return {"ok": True, "worlds": worlds}

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

    # Hedef bölgede boş nokta bul (köyler arası en az 9 kare mesafe)
    cursor.execute("SELECT x, y FROM villages WHERE world_id = ?", (req.world_id,))
    taken = [(r["x"], r["y"]) for r in cursor.fetchall()]

    tx, ty = req.target_x, req.target_y
    min_dist = 9
    spot = None
    for r in range(0, 90):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if r > 0 and max(abs(dx), abs(dy)) != r:
                    continue
                cx, cy = max(5, min(195, tx + dx)), max(5, min(195, ty + dy))
                if all(max(abs(cx - ox), abs(cy - oy)) >= min_dist for ox, oy in taken):
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

    # Süre (Sn) - İlk 7 gün 2x hız çarpanı
    speed = get_effective_speed(conn, v_dict, now, user)
    duration = max(5, int(round((60 * math.pow(1.18, cur_lvl)) / speed)))
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

    speed = get_effective_speed(conn, v_dict, now, user)
    duration = max(2, int(round((u_cost["time"] * req.count) / speed)))
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

    # Mesafe ve Süre Hesabı - İlk 7 gün 2x birim hızı
    dx = float(from_v["x"] - to_v["x"])
    dy = float(from_v["y"] - to_v["y"])
    dist = math.sqrt(dx * dx + dy * dy)
    speed = get_effective_speed(conn, from_dict, now, user)
    duration = max(15, int(round((dist * 60) / speed))) # Alan başına 60 sn / hız çarpanı
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
    now = int(time.time())
    conn = get_db()
    cursor = conn.cursor()
    ensure_cloud_saves_table(cursor, conn.is_pg)
    cloud_state, cloud_updated_unix, server_village = _fetch_cloud_and_village(
        cursor, user["id"], user["display_name"]
    )
    worlds_meta = _sync_worlds_table_from_states(cursor, now)
    conn.commit()
    conn.close()
    if cloud_state is not None:
        return {
            "ok": True,
            "has_save": True,
            "state": cloud_state,
            "cloud_state": cloud_state,
            "worlds_meta": worlds_meta,
            "server_village": server_village,
            "updated_unix": cloud_updated_unix
        }
    if server_village is not None:
        return {
            "ok": True,
            "has_save": True,
            "state": None,
            "cloud_state": None,
            "worlds_meta": worlds_meta,
            "server_village": server_village,
            "updated_unix": int(server_village.get("last_calc_unix", 0))
        }
    return {"ok": True, "has_save": False, "state": None, "cloud_state": None, "worlds_meta": worlds_meta, "server_village": None, "updated_unix": 0}


@app.post("/api/game/save")
def post_cloud_save(payload: Dict[str, Any], user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    if isinstance(payload, dict) and isinstance(payload.get("state"), dict) and "world_id" not in payload:
        state_obj = payload["state"]
    else:
        state_obj = payload if isinstance(payload, dict) else {}

    w_id = int(
        (state_obj.get("world_id") if isinstance(state_obj, dict) else None)
        or (state_obj.get("state", {}).get("world", {}).get("world_id") if isinstance(state_obj, dict) and isinstance(state_obj.get("state"), dict) else None)
        or (state_obj.get("world", {}).get("world_id") if isinstance(state_obj, dict) and isinstance(state_obj.get("world"), dict) else None)
        or 1
    )
    if w_id < 1 or w_id > WORLDS_COUNT:
        w_id = 1

    conn = get_db()
    merged_for_player = None
    worlds_meta: List[Dict[str, Any]] = []
    with conn:
        cursor = conn.cursor()
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _migrate_legacy_cloud_saves_to_world_states(cursor, now)

        cursor.execute("SELECT state_json FROM world_states WHERE world_id = ?", (w_id,))
        ws_row = cursor.fetchone()
        server_w = None
        if ws_row:
            try:
                server_w = json.loads(ws_row["state_json"])
            except Exception:
                server_w = None

        merged_w = merge_world_state(server_w, state_obj, user["display_name"], now)
        merged_json = json.dumps(merged_w, ensure_ascii=False)
        if ws_row:
            cursor.execute(
                "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                (merged_json, now, w_id)
            )
        else:
            cursor.execute(
                "INSERT INTO world_states (world_id, state_json, updated_unix) VALUES (?, ?, ?)",
                (w_id, merged_json, now)
            )

        merged_for_player = _prepare_world_for_player(merged_w, user["display_name"])
        player_save_json = json.dumps(merged_for_player, ensure_ascii=False)
        cursor.execute("SELECT user_id FROM cloud_saves WHERE user_id = ?", (user["id"],))
        if cursor.fetchone():
            cursor.execute(
                "UPDATE cloud_saves SET state_json = ?, updated_unix = ? WHERE user_id = ?",
                (player_save_json, now, user["id"])
            )
        else:
            cursor.execute(
                "INSERT INTO cloud_saves (user_id, state_json, updated_unix) VALUES (?, ?, ?)",
                (user["id"], player_save_json, now)
            )

        worlds_meta = _sync_worlds_table_from_states(cursor, now)

    return {
        "ok": True,
        "updated_unix": now,
        "world_id": w_id,
        "cloud_state": merged_for_player,
        "worlds_meta": worlds_meta,
    }


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
