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
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
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
        conn = psycopg2.connect(db_url, connect_timeout=5)
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
                last_login_unix {0} NOT NULL,
                diamonds INTEGER DEFAULT 35,
                scrolls_json TEXT DEFAULT '{{}}'
            )""".format(bigint_t),

            """CREATE TABLE IF NOT EXISTS iap_transactions (
                transaction_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                pack_id TEXT NOT NULL,
                diamonds_added INTEGER NOT NULL,
                platform TEXT NOT NULL DEFAULT 'ios',
                receipt_data TEXT DEFAULT '',
                created_unix {0} NOT NULL
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
        _ensure_users_store_columns(cursor, conn.is_pg)

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
    if not IS_POSTGRES:
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
    display_name: str = Field(..., min_length=1, max_length=60)
    email: Optional[str] = Field(None, max_length=120)
    provider_uid: Optional[str] = Field(None, max_length=160)
    identity_token: Optional[str] = Field(None, max_length=4096)


class CheckAccountRequest(BaseModel):
    provider: str = Field(..., max_length=20)
    email: Optional[str] = Field(None, max_length=120)
    provider_uid: Optional[str] = Field(None, max_length=160)
    identity_token: Optional[str] = Field(None, max_length=4096)

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


class BuyScrollRequest(BaseModel):
    scroll_id: str = Field(..., min_length=2, max_length=60)
    qty: int = Field(1, ge=1, le=999)


class UseScrollRequest(BaseModel):
    scroll_id: str = Field(..., min_length=2, max_length=60)
    category: Optional[str] = Field(None, max_length=30)
    target_id: Optional[Any] = Field(None)
    village_id: Optional[int] = Field(None)


class BuyResourcesRequest(BaseModel):
    pack_id: str = Field(..., min_length=2, max_length=60)
    village_id: Optional[int] = Field(None)


class VerifyIapRequest(BaseModel):
    product_id: str = Field(..., min_length=2, max_length=120)
    transaction_id: str = Field(..., min_length=2, max_length=200)
    pack_id: Optional[str] = Field(None, max_length=60)
    platform: str = Field("ios", max_length=40)
    receipt_data: Optional[str] = Field("", max_length=32768)

# -----------------------------------------------------------------------------
# Kimlik Doğrulama / Yetkilendirme (Bearer Token Dependency)
# -----------------------------------------------------------------------------
def get_current_user(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Yetkilendirme başlığı eksik veya geçersiz.")
    token = authorization.replace("Bearer ", "").strip()

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE token = ?", (token,))
        user = cursor.fetchone()

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

def _row_first_int(row) -> int:
    if not row:
        return 0
    return int((list(row.values())[0] if isinstance(row, dict) else row[0]) or 0)


@app.get("/api")
@app.get("/api/")
@app.get("/api/health")
def health():
    db_status = "ok"
    u_count = 0
    real_villages = 0
    bot_villages = 0
    err_msg = None
    conn = None
    try:
        now = int(time.time())
        conn = get_db()
        with conn:
            cursor = conn.cursor()
            if conn.is_pg:
                cursor.execute("SET LOCAL statement_timeout = '4000'")
            ensure_cloud_saves_table(cursor, conn.is_pg)
            _ensure_world_reset_epoch(cursor, now)
            _ensure_world1_bots_seeded(cursor, now)
            cursor.execute("SELECT COUNT(*) FROM users")
            u_count = _row_first_int(cursor.fetchone())
            cursor.execute("SELECT COUNT(*) FROM villages WHERE is_bot = 0")
            real_villages = _row_first_int(cursor.fetchone())
            cursor.execute("SELECT COUNT(*) FROM villages WHERE world_id = 1 AND is_bot = 1")
            bot_villages = _row_first_int(cursor.fetchone())
    except Exception as e:
        db_status = "error"
        err_msg = str(e)
        bot_villages = 0
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass

    return {
        "status": "online",
        "game": "Taht ve Kılıç (KingsAge 2)",
        "engine": "Authoritative Serverless Engine (Vercel/Cloudflare)",
        "db_mode": "Supabase PostgreSQL (Pooler)" if IS_POSTGRES else "SQLite WAL",
        "db_status": db_status,
        "db_error": err_msg,
        "world_reset_epoch": WORLD_RESET_EPOCH,
        "march_speed_boost": MARCH_SPEED_BOOST,
        "registered_players": u_count,
        "real_player_villages": real_villages,
        "world1_bot_villages": bot_villages,
        "server_time_unix": int(time.time()),
        "security": "100% Parameterized SQL (Injection-Proof), Bearer Auth, Server-Authoritative"
    }


WORLD_RESET_EPOCH = 5
MARCH_SPEED_BOOST = 1.5
MAX_REAL_PLAYERS_PER_WORLD = 100
WORLDS_COUNT = 10
MAP_SIZE = 200
MIN_VILLAGE_DISTANCE = 9

STARTER_DIAMONDS = 35

DIAMOND_PACKS: List[Dict[str, Any]] = [
    {"id": "diamonds_10", "product_id": "com.tahtkilic.kingsage2.diamonds_10", "name": "Avuç Dolusu Elmas", "diamonds": 10, "badge": "Başlangıç", "usd": "$0.99", "eur": "€0.99", "try": "₺49,99"},
    {"id": "diamonds_50", "product_id": "com.tahtkilic.kingsage2.diamonds_50", "name": "Kese Elmas", "diamonds": 50, "badge": "+%10 Değer", "usd": "$4.99", "eur": "€5.99", "try": "₺249,99"},
    {"id": "diamonds_100", "product_id": "com.tahtkilic.kingsage2.diamonds_100", "name": "Hazine Sandığı", "diamonds": 100, "badge": "⭐ En Popüler", "usd": "$7.99", "eur": "€8.99", "try": "₺399,99"},
    {"id": "diamonds_250", "product_id": "com.tahtkilic.kingsage2.diamonds_250", "name": "Kraliyet Kasası", "diamonds": 250, "badge": "+%30 Değer", "usd": "$17.99", "eur": "€19.99", "try": "₺999,99"},
    {"id": "diamonds_1000", "product_id": "com.tahtkilic.kingsage2.diamonds_1000", "name": "İmparator Hazinesi", "diamonds": 1000, "badge": "👑 En İyi Değer", "usd": "$59.99", "eur": "€69.99", "try": "₺2.999,99"},
]

SPEEDUP_SCROLLS: List[Dict[str, Any]] = [
    {"id": "build_10m", "category": "build", "seconds": 600, "cost_diamonds": 5, "name": "İnşaat 10 Dk"},
    {"id": "build_30m", "category": "build", "seconds": 1800, "cost_diamonds": 12, "name": "İnşaat 30 Dk"},
    {"id": "build_60m", "category": "build", "seconds": 3600, "cost_diamonds": 20, "name": "İnşaat 1 Saat"},
    {"id": "train_10m", "category": "train", "seconds": 600, "cost_diamonds": 5, "name": "Asker Eğitimi 10 Dk"},
    {"id": "train_30m", "category": "train", "seconds": 1800, "cost_diamonds": 12, "name": "Asker Eğitimi 30 Dk"},
    {"id": "train_60m", "category": "train", "seconds": 3600, "cost_diamonds": 20, "name": "Asker Eğitimi 1 Saat"},
    {"id": "research_10m", "category": "research", "seconds": 600, "cost_diamonds": 6, "name": "Araştırma 10 Dk"},
    {"id": "research_30m", "category": "research", "seconds": 1800, "cost_diamonds": 15, "name": "Araştırma 30 Dk"},
    {"id": "research_60m", "category": "research", "seconds": 3600, "cost_diamonds": 25, "name": "Araştırma 1 Saat"},
    {"id": "march_10m", "category": "march", "seconds": 600, "cost_diamonds": 8, "name": "Sefer Hızlandırma 10 Dk"},
    {"id": "march_30m", "category": "march", "seconds": 1800, "cost_diamonds": 18, "name": "Sefer Hızlandırma 30 Dk"},
    {"id": "march_60m", "category": "march", "seconds": 3600, "cost_diamonds": 30, "name": "Sefer Hızlandırma 1 Saat"},
]

RESOURCE_PACKS: List[Dict[str, Any]] = [
    {"id": "res_wood_1000", "name": "1.000 Odun Sandığı", "cost_diamonds": 5, "wood": 1000, "stone": 0, "iron": 0, "fill_storage": False, "badge": "Kereste", "description": "Aktif köy ambarına anında +1.000 Odun ekler."},
    {"id": "res_stone_1000", "name": "1.000 Taş Sandığı", "cost_diamonds": 5, "wood": 0, "stone": 1000, "iron": 0, "fill_storage": False, "badge": "Taş Blok", "description": "Aktif köy ambarına anında +1.000 Taş ekler."},
    {"id": "res_iron_1000", "name": "1.000 Demir Sandığı", "cost_diamonds": 5, "wood": 0, "stone": 0, "iron": 1000, "fill_storage": False, "badge": "Cevher", "description": "Aktif köy ambarına anında +1.000 Demir ekler."},
    {"id": "res_bundle_1500", "name": "Kraliyet Erzak Paketi (+1.500 Tümü)", "cost_diamonds": 12, "wood": 1500, "stone": 1500, "iron": 1500, "fill_storage": False, "badge": "⭐ Avantajlı", "description": "Aktif köye +1.500 Odun, +1.500 Taş ve +1.500 Demir ekler."},
    {"id": "res_bundle_5000", "name": "İmparatorluk Hazine Kervanı (+5.000 Tümü)", "cost_diamonds": 35, "wood": 5000, "stone": 5000, "iron": 5000, "fill_storage": False, "badge": "👑 Büyük Paket", "description": "Aktif köye +5.000 Odun, +5.000 Taş ve +5.000 Demir ekler."},
    {"id": "res_fill_storage", "name": "Ambarları Doldur (%100 Tam Depo)", "cost_diamonds": 100, "wood": 0, "stone": 0, "iron": 0, "fill_storage": True, "badge": "🏛️ Tam Kapasite", "description": "Aktif köyün Odun, Taş ve Demir ambarlarını Depo kapasitesinin %100'üne doldurur."},
]


_PG_SCHEMA_INITIALIZED = False
_PG_EPOCH_VERIFIED = False
_PG_BOTS_VERIFIED = False
_PG_WORLDS_VERIFIED = False
_PG_LEGACY_MIGRATED = False


def _ensure_users_store_columns(cursor, is_pg: bool) -> None:
    if is_pg:
        cursor.execute(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name IN ('diamonds', 'scrolls_json', 'provider_uid')"
        )
        existing_cols = {
            str((r["column_name"] if isinstance(r, dict) else r[0])).lower()
            for r in cursor.fetchall()
        }
        missing = [
            col for col, _ddl in (
                ("diamonds", "ALTER TABLE users ADD COLUMN IF NOT EXISTS diamonds INTEGER DEFAULT 35"),
                ("scrolls_json", "ALTER TABLE users ADD COLUMN IF NOT EXISTS scrolls_json TEXT DEFAULT '{}'"),
                ("provider_uid", "ALTER TABLE users ADD COLUMN IF NOT EXISTS provider_uid TEXT DEFAULT ''"),
            ) if col not in existing_cols
        ]
        if not missing:
            return
        cursor.execute("SET LOCAL lock_timeout = '2000'")
        for col, ddl in (
            ("diamonds", "ALTER TABLE users ADD COLUMN IF NOT EXISTS diamonds INTEGER DEFAULT 35"),
            ("scrolls_json", "ALTER TABLE users ADD COLUMN IF NOT EXISTS scrolls_json TEXT DEFAULT '{}'"),
            ("provider_uid", "ALTER TABLE users ADD COLUMN IF NOT EXISTS provider_uid TEXT DEFAULT ''"),
        ):
            if col in missing:
                cursor.execute(ddl)
        return
    cursor.execute("PRAGMA table_info(users)")
    cols = set()
    for r in cursor.fetchall():
        col_name = r["name"] if isinstance(r, dict) else r[1]
        cols.add(str(col_name).lower())
    if "diamonds" not in cols:
        cursor.execute("ALTER TABLE users ADD COLUMN diamonds INTEGER DEFAULT 35")
    if "scrolls_json" not in cols:
        cursor.execute("ALTER TABLE users ADD COLUMN scrolls_json TEXT DEFAULT '{}'")
    if "provider_uid" not in cols:
        cursor.execute("ALTER TABLE users ADD COLUMN provider_uid TEXT DEFAULT ''")


def _parse_user_wallet(user_row: Optional[Dict[str, Any]]) -> tuple:
    if not user_row:
        return STARTER_DIAMONDS, {}
    raw_d = user_row.get("diamonds")
    diamonds = STARTER_DIAMONDS if raw_d is None else max(0, int(raw_d))
    raw_s = user_row.get("scrolls_json")
    scrolls: Dict[str, int] = {}
    if isinstance(raw_s, dict):
        parsed_s = raw_s
    elif isinstance(raw_s, str) and raw_s.strip():
        try:
            parsed_s = json.loads(raw_s)
        except Exception:
            parsed_s = {}
    else:
        parsed_s = {}
    if isinstance(parsed_s, dict):
        for k, v in parsed_s.items():
            cnt = max(0, int(v or 0))
            if cnt > 0:
                scrolls[str(k)] = cnt
    return diamonds, scrolls


def _sync_wallet_to_world_profiles(cursor, display_name: str, diamonds: int, scrolls: Dict[str, int], now: int) -> None:
    norm_p = _norm_p_name(display_name)
    if not norm_p:
        return
    cursor.execute("SELECT world_id, state_json FROM world_states ORDER BY world_id ASC")
    for ws in cursor.fetchall():
        wid = int(ws["world_id"])
        try:
            w_data = json.loads(ws["state_json"])
        except Exception:
            continue
        state = w_data.get("state")
        if not isinstance(state, dict):
            continue
        w_dict = state.setdefault("world", {})
        profs = w_dict.get("player_profiles")
        if not isinstance(profs, dict):
            continue
        updated = False
        for pk, pv in profs.items():
            if _matches_player(pk, norm_p) and isinstance(pv, dict):
                pv["diamonds"] = max(0, int(diamonds))
                pv["scrolls"] = copy.deepcopy(scrolls)
                updated = True
        if isinstance(state.get("player"), dict) and _matches_player(str(state["player"].get("name", "")), norm_p):
            state["player"]["diamonds"] = max(0, int(diamonds))
            state["player"]["scrolls"] = copy.deepcopy(scrolls)
            updated = True
        if updated:
            cursor.execute(
                "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                (json.dumps(w_data, ensure_ascii=False), now, wid),
            )

WORLD1_BOT_NAMES = [
    "Lord Edward", "Baron Roland", "Kont Vlad", "Dük William", "Prens Arthur",
    "Lord Richard", "Baron Godfrey", "Kont Baldwin", "Dük Robert", "Lord Henry",
    "Baron Simon", "Kont Raymond", "Dük Geoffrey", "Lord Stephen", "Baron Guy",
    "Kont Bohemond", "Dük Tancred", "Lord Walter", "Baron Hugh", "Kont Peter",
    "Lord Gareth", "Baron Tristram", "Kont Lancelot", "Dük Galahad", "Lord Percival",
    "Lord Bedivere", "Baron Kay", "Kont Lamorak", "Dük Gawain", "Lord Geraint",
    "Baron Bors", "Kont Gaheris", "Dük Agravain", "Lord Ywain", "Baron Gareth II",
    "Kont Dinadan", "Dük Palamedes", "Lord Sagramore", "Baron Lucan", "Kont Ector",
    "Lord Colgrevance", "Baron Safir", "Kont Segwarides", "Dük Pelleas", "Lord Marhaus",
    "Baron Dagonet", "Kont Tor", "Dük Bleoberis", "Lord Cador", "Baron Morholt",
]

POINTS_PER_LEVEL_PY = {
    "main": 20, "stone": 20, "wood": 20, "iron": 20, "storage": 20, "farm": 10,
    "barracks": 20, "wall": 20, "market": 20, "stable": 10, "hide": 10,
    "garage": 20, "snob": 100, "smith": 40, "statue": 1000,
}

def _calc_village_points(blds: Dict[str, Any]) -> int:
    return sum(int(POINTS_PER_LEVEL_PY.get(str(k), 0)) * int(v or 0) for k, v in (blds or {}).items())

def _build_world1_bot_villages(now: int) -> List[Dict[str, Any]]:
    rng = random.Random(1001)
    placed: List[tuple] = []
    out: List[Dict[str, Any]] = []
    for idx, bname in enumerate(WORLD1_BOT_NAMES, start=1):
        bx, by = 15, 15
        for _ in range(300):
            cx = rng.randint(15, 185)
            cy = rng.randint(15, 185)
            # Keep central spawn area around (100, 100) clear
            if abs(cx - 100) < 11 and abs(cy - 100) < 11:
                continue
            if all(max(abs(cx - ox), abs(cy - oy)) >= MIN_VILLAGE_DISTANCE for ox, oy in placed):
                bx, by = cx, cy
                break
        placed.append((bx, by))
        tier_boost = idx % 3
        blds = {
            "main": 1 + (tier_boost >= 1),
            "farm": 1 + (tier_boost >= 1),
            "wood": 1 + (idx % 2),
            "stone": 1 + ((idx + 1) % 2),
            "iron": 1 + (tier_boost == 2),
            "storage": 1 + (tier_boost >= 1),
            "barracks": 1 if idx % 2 == 0 else 0,
            "wall": 1 if idx % 3 == 0 else 0,
            "hide": 1,
        }
        pts = _calc_village_points(blds)
        units = {"spear": 4 + (idx % 7), "sword": (2 + idx % 4) if blds["barracks"] > 0 else 0}
        out.append({
            "id": idx,
            "name": f"Kale {bname}",
            "x": bx,
            "y": by,
            "owner": bname,
            "points": pts,
            "realm_of_power": pts,
            "is_bot": True,
            "is_barbarian": False,
            "bonus_type": "",
            "buildings": blds,
            "resources": {"wood": 800, "stone": 800, "iron": 800},
            "units": units,
            "researched": {"spear": True, "sword": True} if blds["barracks"] > 0 else {"spear": True},
            "support": [],
            "protection_until": 0,
            "conquest_protection_until": 0,
            "last_sim_unix": now,
        })
    return out


def _ensure_world1_bots_seeded(cursor, now: int) -> None:
    global _PG_BOTS_VERIFIED
    if getattr(cursor, "is_pg", False) and _PG_BOTS_VERIFIED:
        return
    cursor.execute("SELECT COUNT(*) FROM villages WHERE world_id = 1 AND is_bot = 1")
    bot_cnt_row = cursor.fetchone()
    bot_cnt = int((list(bot_cnt_row.values())[0] if isinstance(bot_cnt_row, dict) else bot_cnt_row[0]) or 0) if bot_cnt_row else 0
    bots = None
    if bot_cnt < 50:
        bots = _build_world1_bot_villages(now)
        for bv in bots:
            cursor.execute("SELECT id FROM villages WHERE id = ?", (bv["id"],))
            if not cursor.fetchone():
                cursor.execute("""
                    INSERT INTO villages (
                        id, world_id, user_id, name, x, y, owner, points, is_bot, is_barbarian,
                        buildings_json, resources_json, units_json, last_calc_unix, protection_until_unix
                    ) VALUES (?, 1, NULL, ?, ?, ?, ?, ?, 1, 0, ?, ?, ?, ?, 0)
                """, (
                    bv["id"], bv["name"], bv["x"], bv["y"], bv["owner"], bv["points"],
                    json.dumps(bv["buildings"]), json.dumps(bv["resources"]), json.dumps(bv["units"]), now
                ))

    cursor.execute("SELECT state_json FROM world_states WHERE world_id = 1")
    ws_row = cursor.fetchone()
    if not ws_row:
        if bots is None:
            bots = _build_world1_bot_villages(now)
        tiles = {f"{bv['x']},{bv['y']}": bv["id"] for bv in bots}
        w1_payload = {
            "world_id": 1,
            "world_name": "Dünya 1",
            "seed": 1001,
            "created_unix": now,
            "last_saved_unix": now,
            "last_bot_sim_unix": now,
            "registered_real_players": [],
            "state": {
                "world": {
                    "world_id": 1,
                    "seed": 1001,
                    "size": MAP_SIZE,
                    "sim_now_unix": now,
                    "base_speed": 1.0,
                    "base_unit_speed": 1.0,
                    "speed": 2.0,
                    "unit_speed": 2.0,
                    "starter_boost_days": 7,
                    "tiles": tiles,
                    "villages": bots,
                    "player_profiles": {},
                    "player_starter_boost": {},
                },
                "villages": bots,
                "queues": [],
                "movements": [],
                "reports": [],
                "messages": [],
                "alliances": [],
            },
        }
        cursor.execute(
            "INSERT INTO world_states (world_id, state_json, updated_unix) VALUES (1, ?, ?)",
            (json.dumps(w1_payload, ensure_ascii=False), now),
        )
    else:
        try:
            w_data = json.loads(ws_row["state_json"])
            st = w_data.setdefault("state", {})
            vills = st.get("villages") or []
            existing_bot_cnt = sum(1 for v in vills if isinstance(v, dict) and bool(v.get("is_bot", False)))
            if existing_bot_cnt == 0:
                if bots is None:
                    bots = _build_world1_bot_villages(now)
                existing_ids = {int(v.get("id", 0) or 0) for v in vills if isinstance(v, dict)}
                occupied = {(int(v.get("x", 0) or 0), int(v.get("y", 0) or 0)) for v in vills if isinstance(v, dict)}
                for bv in bots:
                    if bv["id"] in existing_ids:
                        continue
                    if not _is_spot_free_dist(occupied, bv["x"], bv["y"], MIN_VILLAGE_DISTANCE, MAP_SIZE):
                        nx, ny = _find_free_spot_on_server(vills, bv["x"], bv["y"], MIN_VILLAGE_DISTANCE, MAP_SIZE)
                        bv["x"], bv["y"] = nx, ny
                    occupied.add((bv["x"], bv["y"]))
                    vills.append(bv)
                st["villages"] = sorted(vills, key=lambda v: int(v.get("id", 0) or 0))
                _rebuild_tiles(st)
                cursor.execute(
                    "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = 1",
                    (json.dumps(w_data, ensure_ascii=False), now),
                )
        except Exception:
            pass
    if getattr(cursor, "is_pg", False):
        _PG_BOTS_VERIFIED = True


def _simulate_server_bots(w_data: Dict[str, Any], cursor, now: int) -> bool:
    """Barışçıl bot gelişimi: 50 bot köyü binalarını geliştirir ve asker eğitir; kimseye saldırmaz."""
    if not isinstance(w_data, dict):
        return False
    last_sim = int(w_data.get("last_bot_sim_unix", 0) or 0)
    elapsed = now - last_sim
    if elapsed < 300:
        return False
    elapsed = min(elapsed, 86400)
    st = w_data.get("state")
    if not isinstance(st, dict):
        return False
    vills = st.get("villages")
    if not isinstance(vills, list):
        return False

    build_steps = max(1, min(6, elapsed // 180))
    changed = False
    for v in vills:
        if not isinstance(v, dict) or not bool(v.get("is_bot", False)):
            continue
        blds = v.setdefault("buildings", {})
        res = v.setdefault("resources", {"wood": 800, "stone": 800, "iron": 800})
        units = v.setdefault("units", {})

        # Kaynak üretimi
        stor_lvl = max(1, int(blds.get("storage", 1) or 1))
        cap = int(round(1000 * (1.23 ** (stor_lvl - 1))))
        for rk in ("wood", "stone", "iron"):
            lvl = max(1, int(blds.get(rk, 1) or 1))
            rate_hr = 30.0 * (1.16 ** (lvl - 1)) * 2.0
            res[rk] = min(cap, int(res.get(rk, 0) or 0) + int(rate_hr * elapsed / 3600.0))

        # Barışçıl köy geliştirme ve asker eğitimi (botlar kimseye saldırmaz)
        did_upgrade = False
        for _ in range(build_steps):
            # Kışla açmayı teşvik et (gerekli önkoşullar main 3, farm 3, storage 3 -> sonra barracks 1)
            target_order = ["wood", "stone", "iron", "farm", "storage", "main", "barracks", "wall", "hide"]
            if int(blds.get("main", 1) or 1) >= 3 and int(blds.get("farm", 1) or 1) >= 3 and int(blds.get("storage", 1) or 1) >= 3 and int(blds.get("barracks", 0) or 0) < 1:
                pick = "barracks"
            else:
                pick = min(target_order, key=lambda k: (int(blds.get(k, 0) or 0), target_order.index(k)))
                if pick == "barracks" and int(blds.get("barracks", 0) or 0) == 0:
                    if int(blds.get("main", 1) or 1) < 3:
                        pick = "main"
                    elif int(blds.get("farm", 1) or 1) < 3:
                        pick = "farm"
                    elif int(blds.get("storage", 1) or 1) < 3:
                        pick = "storage"

            cur_lvl = int(blds.get(pick, 0) or 0)
            max_lvl = 25 if pick in ("wood", "stone", "iron", "farm", "storage", "main") else 15
            if cur_lvl < max_lvl:
                cost = int(65 * (1.32 ** cur_lvl))
                if res.get("wood", 0) >= cost and res.get("stone", 0) >= cost and res.get("iron", 0) >= cost:
                    res["wood"] -= cost
                    res["stone"] -= cost
                    res["iron"] -= cost
                    blds[pick] = cur_lvl + 1
                    did_upgrade = True

            # Kışlası açık botlar asker üretir (kışla yoksa temel çiftçi milisi)
            if int(blds.get("barracks", 0) or 0) >= 1:
                total_u = sum(int(val or 0) for val in units.values())
                add_n = 2
                if total_u < 120 and res.get("wood", 0) >= 50 * add_n and res.get("stone", 0) >= 30 * add_n and res.get("iron", 0) >= 40 * add_n:
                    uk = "spear" if (total_u % 2 == 0) else "sword"
                    res["wood"] -= 50 * add_n
                    res["stone"] -= 30 * add_n
                    res["iron"] -= 40 * add_n
                    units[uk] = int(units.get(uk, 0) or 0) + add_n
                    v.setdefault("researched", {})["spear"] = True
                    v["researched"]["sword"] = True
                    did_upgrade = True

        if did_upgrade:
            pts = _calc_village_points(blds)
            v["points"] = pts
            v["realm_of_power"] = pts
            v["last_sim_unix"] = now
            changed = True

    w_data["last_bot_sim_unix"] = now
    return changed


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
    global _PG_WORLDS_VERIFIED
    if getattr(cursor, "is_pg", False) and _PG_WORLDS_VERIFIED:
        return
    cursor.execute("SELECT id FROM worlds")
    existing_ids = {int((r["id"] if isinstance(r, dict) else r[0]) or 0) for r in cursor.fetchall()}
    for wid in range(1, WORLDS_COUNT + 1):
        if wid not in existing_ids:
            cursor.execute(
                """INSERT INTO worlds (id, name, seed, is_active, created_unix, registered_players)
                   VALUES (?, ?, ?, ?, ?, 0)""",
                (wid, f"Dünya {wid}", 1000 + wid, 1 if wid == 1 else 0, now)
            )
    if getattr(cursor, "is_pg", False):
        _PG_WORLDS_VERIFIED = True


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


def _prepare_world_for_player(
    world_w: Optional[Dict[str, Any]],
    player_name: str,
    user_wallet: Optional[Dict[str, Any]] = None,
) -> Optional[Dict[str, Any]]:
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

    # Yaşayan köyü olan oyuncuda veya geçersiz/boş fatih kaydında bayat defeated_info'yu temizle
    if owned_vids:
        found_prof.pop("defeated_info", None)
        for pk, pv in profiles.items():
            if _matches_player(pk, norm_p) and isinstance(pv, dict):
                pv.pop("defeated_info", None)
    else:
        for prof_obj in ([found_prof] + [pv for pk, pv in profiles.items() if _matches_player(pk, norm_p) and isinstance(pv, dict)]):
            di = prof_obj.get("defeated_info")
            if di is not None:
                conq_name = str(di.get("conqueror", "")).strip() if isinstance(di, dict) else ""
                if not isinstance(di, dict) or not conq_name or _matches_player(conq_name, norm_p):
                    prof_obj.pop("defeated_info", None)

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

    w_dict = state.setdefault("world", {})
    if boost_u > 0:
        w_dict["starter_boost_until_unix"] = boost_u
    if created_u > 0:
        w_dict["player_joined_unix"] = created_u

    p_diamonds = STARTER_DIAMONDS
    if user_wallet is not None and user_wallet.get("diamonds") is not None:
        p_diamonds = max(0, int(user_wallet["diamonds"]))
    elif found_prof.get("diamonds") is not None:
        p_diamonds = max(0, int(found_prof["diamonds"]))

    p_scrolls: Dict[str, int] = {}
    if user_wallet is not None and isinstance(user_wallet.get("scrolls"), dict):
        p_scrolls = copy.deepcopy(user_wallet["scrolls"])
    elif isinstance(found_prof.get("scrolls"), dict):
        p_scrolls = copy.deepcopy(found_prof["scrolls"])

    if norm_p and isinstance(profiles, dict):
        for pk, pv in profiles.items():
            if _matches_player(pk, norm_p) and isinstance(pv, dict):
                pv["diamonds"] = p_diamonds
                pv["scrolls"] = copy.deepcopy(p_scrolls)

    prof_del_sigs = [str(x) for x in (found_prof.get("deleted_report_sigs") or []) if str(x)]
    prof_read_sigs = [str(x) for x in (found_prof.get("read_report_sigs") or []) if str(x)]
    del_sig_set = set(prof_del_sigs)
    read_sig_set = set(prof_read_sigs)
    prof_del_msg_sigs = [str(x) for x in (found_prof.get("deleted_message_sigs") or []) if str(x)]
    prof_read_msg_sigs = [str(x) for x in (found_prof.get("read_message_sigs") or []) if str(x)]
    del_msg_set = set(prof_del_msg_sigs)
    read_msg_set = set(prof_read_msg_sigs)

    # Akıllı Tutorial tamamlanma koruması (çoklu köy / mezuniyet / ileri seviye binalar)
    tut_completed = bool(found_prof.get("tutorial_completed", False))
    tut_skipped = bool(found_prof.get("tutorial_skipped", False))
    tut_step = int(found_prof.get("tutorial_step", 0) or 0)
    tut_reward_claimed = bool(found_prof.get("tutorial_reward_claimed", False))
    if not tut_completed:
        if tut_skipped or tut_reward_claimed or tut_step >= 18 or len(owned_vids) > 1:
            tut_completed = True
        elif tut_step == 0:
            for v in villages:
                if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), norm_p):
                    vb = v.get("buildings") if isinstance(v.get("buildings"), dict) else {}
                    if (
                        int(vb.get("main", 1) or 1) >= 4
                        or int(vb.get("stable", 0) or 0) >= 1
                        or int(vb.get("market", 0) or 0) >= 1
                        or int(vb.get("garage", 0) or 0) >= 1
                        or int(vb.get("snob", 0) or 0) >= 1
                    ):
                        tut_completed = True
                        break

    # Oyuncu için silinen raporları gizle ve okunanların unread bayrağını senkronize et
    if isinstance(state.get("reports"), list):
        filtered_reps = []
        for rep in state["reports"]:
            if not isinstance(rep, dict):
                continue
            rsig_str = _report_sig_str(rep)
            if rsig_str in del_sig_set:
                continue
            if rsig_str in read_sig_set:
                rep["unread"] = False
            filtered_reps.append(rep)
        state["reports"] = filtered_reps

    # Oyuncu için mükerrer (özellikle Hoş Geldiniz) mesajları birleştir, silinenleri gizle ve okunanları senkronize et
    if isinstance(state.get("messages"), list):
        dedup_msgs: List[Dict[str, Any]] = []
        msg_pos: Dict[str, int] = {}
        for raw_m in state["messages"]:
            if not isinstance(raw_m, dict):
                continue
            m = copy.deepcopy(raw_m)
            m_to = str(m.get("to", m.get("to_name", ""))).strip()
            m_from = str(m.get("from", m.get("from_name", ""))).strip()
            is_for_player = (not norm_p) or _matches_player(m_to, norm_p) or _matches_player(m_from, norm_p)
            msig_str = _message_sig_str(m)
            if is_for_player and msig_str in del_msg_set:
                continue
            if is_for_player and msig_str in read_msg_set:
                m["read"] = True
            if msig_str in msg_pos:
                prev_m = dedup_msgs[msg_pos[msig_str]]
                if bool(m.get("read", False)) or msig_str in read_msg_set:
                    prev_m["read"] = True
                continue
            msg_pos[msig_str] = len(dedup_msgs)
            dedup_msgs.append(m)
        state["messages"] = dedup_msgs

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
        "restarted_unix": int(found_prof.get("restarted_unix", 0) or 0),
        "tutorial_completed": tut_completed,
        "tutorial_skipped": tut_skipped,
        "tutorial_step": tut_step,
        "tutorial_reward_claimed": tut_reward_claimed,
        "quests": copy.deepcopy(q_dict),
        "gold_armour": int(found_prof.get("gold_armour", 0) or 0),
        "diamonds": p_diamonds,
        "scrolls": p_scrolls,
        "read_report_sigs": prof_read_sigs[-400:],
        "deleted_report_sigs": prof_del_sigs[-400:],
        "unread_toggled_sigs": [str(x) for x in (found_prof.get("unread_toggled_sigs") or []) if str(x)][-200:],
        "read_message_sigs": prof_read_msg_sigs[-400:],
        "deleted_message_sigs": prof_del_msg_sigs[-400:],
        "premium": False,
    }
    w["registered_real_players"] = _collect_real_players(w)
    return w


def _rebuild_tiles(state: Dict[str, Any]) -> None:
    w_dict = state.setdefault("world", {})
    tiles: Dict[str, int] = {}
    clean_villages: List[Dict[str, Any]] = []
    for v in (state.get("villages") or []):
        if not isinstance(v, dict):
            continue
        raw_id = v.get("id")
        try:
            vid = int(raw_id) if raw_id is not None else 0
        except Exception:
            vid = 0
        if vid <= 0:
            continue
        clean_villages.append(v)
        tiles[f"{int(v.get('x', 1) or 1)},{int(v.get('y', 1) or 1)}"] = vid
    state["villages"] = clean_villages
    w_dict["tiles"] = tiles
    w_dict["villages"] = clean_villages


def _deduplicate_world_villages(w_data: Optional[Dict[str, Any]], preferred_owner: str = "", preferred_vid: int = -1) -> bool:
    """id <= 0/None geçersiz köyleri siler ve her gerçek oyuncu için fethedilmemiş başlangıç köyünü 1 adet ile sınırlar."""
    if not isinstance(w_data, dict):
        return False
    state = w_data.get("state")
    if not isinstance(state, dict):
        return False
    raw_villages = state.get("villages")
    if not isinstance(raw_villages, list):
        return False

    changed = False
    conquered_vids = set()
    for rep in (state.get("reports") or []):
        if isinstance(rep, dict) and rep.get("type") == "battle":
            rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
            if bool(rdata.get("conquered", False)):
                try:
                    conquered_vids.add(int(rdata.get("target_village_id", 0) or 0))
                except Exception:
                    pass

    starters_by_owner: Dict[str, List[Dict[str, Any]]] = {}
    clean_list: List[Dict[str, Any]] = []
    for v in raw_villages:
        if not isinstance(v, dict):
            changed = True
            continue
        raw_id = v.get("id")
        try:
            vid = int(raw_id) if raw_id is not None else 0
        except Exception:
            vid = 0
        if vid <= 0:
            changed = True
            continue
        v["id"] = vid
        clean_list.append(v)
        if _is_real_player_village(v):
            ok = _norm_p_name(str(v.get("owner", ""))).lower()
            is_conq = (vid in conquered_vids) or bool(v.get("is_conquered", False)) or bool(str(v.get("conquered_by", "")).strip())
            if ok and not is_conq:
                starters_by_owner.setdefault(ok, []).append(v)

    drop_vids = set()
    canonical_by_owner: Dict[str, int] = {}
    pref_norm = _norm_p_name(preferred_owner).lower()
    for ok, arr in starters_by_owner.items():
        if len(arr) <= 1:
            canonical_by_owner[ok] = int(arr[0]["id"])
            continue
        changed = True
        best_v = None
        if ok == pref_norm and preferred_vid > 0:
            for cv in arr:
                if int(cv["id"]) == preferred_vid:
                    best_v = cv
                    break
        if best_v is None:
            best_v = max(arr, key=lambda cv: (int(cv.get("points", 110) or 110), -int(cv["id"])))
        keep_id = int(best_v["id"])
        canonical_by_owner[ok] = keep_id
        for cv in arr:
            if int(cv["id"]) != keep_id:
                drop_vids.add(int(cv["id"]))

    if changed:
        final_villages = [v for v in clean_list if int(v["id"]) not in drop_vids]
        state["villages"] = final_villages
        w_dict = state.setdefault("world", {})
        profs = w_dict.get("player_profiles")
        if isinstance(profs, dict):
            for pk, pv in profs.items():
                if isinstance(pv, dict):
                    onorm = _norm_p_name(pk).lower()
                    if int(pv.get("active_village_id", -1) or -1) in drop_vids and onorm in canonical_by_owner:
                        pv["active_village_id"] = canonical_by_owner[onorm]
        cur_aid = int(state.get("active_village_id", -1) or -1)
        if cur_aid in drop_vids:
            pname = _norm_p_name(str((state.get("player") or {}).get("name", ""))).lower()
            if pname in canonical_by_owner:
                state["active_village_id"] = canonical_by_owner[pname]
        _rebuild_tiles(state)
    return changed


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


def _report_sig_str(rep: Any) -> str:
    t = _report_sig(rep)
    if len(t) < 5:
        return ""
    return f"{t[0]}:{t[1]}:{t[2]}:{t[3]}:{t[4]}"


def _merge_quests_dict(base_q: Any, inc_q: Any) -> Dict[str, Any]:
    bq = base_q if isinstance(base_q, dict) else {}
    iq = inc_q if isinstance(inc_q, dict) else {}
    b_claimed = [str(x) for x in (bq.get("claimed") or []) if str(x)]
    i_claimed = [str(x) for x in (iq.get("claimed") or []) if str(x)]
    claimed = list(dict.fromkeys(b_claimed + i_claimed))

    b_stats = bq.get("stats") if isinstance(bq.get("stats"), dict) else {}
    i_stats = iq.get("stats") if isinstance(iq.get("stats"), dict) else {}
    merged_stats: Dict[str, Any] = copy.deepcopy(b_stats)
    for sk, sv in i_stats.items():
        if sk == "counted_movement_ids":
            b_arr = [str(x) for x in (b_stats.get(sk) or []) if str(x)] if isinstance(b_stats.get(sk), list) else []
            i_arr = [str(x) for x in sv if str(x)] if isinstance(sv, list) else []
            merged_stats[sk] = list(dict.fromkeys(b_arr + i_arr))[-200:]
        elif isinstance(sv, (int, float)) and not isinstance(sv, bool):
            prev_v = b_stats.get(sk, 0)
            prev_num = int(prev_v or 0) if isinstance(prev_v, (int, float)) else 0
            merged_stats[sk] = max(prev_num, int(sv))
        elif sk not in merged_stats:
            merged_stats[sk] = copy.deepcopy(sv)
    return {"claimed": claimed, "stats": merged_stats}


def _merge_player_profile_dicts(base_prof: Any, inc_prof: Any, c_is_newer: bool = True) -> Dict[str, Any]:
    bp = base_prof if isinstance(base_prof, dict) else {}
    ip = inc_prof if isinstance(inc_prof, dict) else {}
    b_restart = int(bp.get("restarted_unix", 0) or 0)
    i_restart = int(ip.get("restarted_unix", 0) or 0)
    if i_restart > b_restart and i_restart > 0:
        res = copy.deepcopy(ip)
        b_del = [str(x) for x in (bp.get("deleted_report_sigs") or []) if str(x)]
        i_del = [str(x) for x in (ip.get("deleted_report_sigs") or []) if str(x)]
        res["deleted_report_sigs"] = list(dict.fromkeys(b_del + i_del))[-400:]
        b_mdel = [str(x) for x in (bp.get("deleted_message_sigs") or []) if str(x)]
        i_mdel = [str(x) for x in (ip.get("deleted_message_sigs") or []) if str(x)]
        res["deleted_message_sigs"] = list(dict.fromkeys(b_mdel + i_mdel))[-400:]
        b_mread = [str(x) for x in (bp.get("read_message_sigs") or []) if str(x)]
        i_mread = [str(x) for x in (ip.get("read_message_sigs") or []) if str(x)]
        res["read_message_sigs"] = list(dict.fromkeys(b_mread + i_mread))[-400:]
        return res

    tut_done = bool(bp.get("tutorial_completed", False)) or bool(ip.get("tutorial_completed", False))
    tut_skip = bool(bp.get("tutorial_skipped", False)) or bool(ip.get("tutorial_skipped", False))
    tut_rew = bool(bp.get("tutorial_reward_claimed", False)) or bool(ip.get("tutorial_reward_claimed", False))
    tut_step = max(int(bp.get("tutorial_step", 0) or 0), int(ip.get("tutorial_step", 0) or 0))
    quests = _merge_quests_dict(bp.get("quests"), ip.get("quests"))

    b_del = [str(x) for x in (bp.get("deleted_report_sigs") or []) if str(x)]
    i_del = [str(x) for x in (ip.get("deleted_report_sigs") or []) if str(x)]
    del_sigs = list(dict.fromkeys(b_del + i_del))[-400:]

    b_read = [str(x) for x in (bp.get("read_report_sigs") or []) if str(x)]
    i_read = [str(x) for x in (ip.get("read_report_sigs") or []) if str(x)]
    i_unreads = {str(x) for x in (ip.get("unread_toggled_sigs") or []) if str(x)}
    b_unreads = {str(x) for x in (bp.get("unread_toggled_sigs") or []) if str(x)}
    if c_is_newer:
        # Yeni istemcide özellikle okunmadı işaretlenenler hariç her iki tarafın okunanlarını birleştir (bayat [] istemci sıfırlamasın)
        effective_unreads = i_unreads - set(i_read)
        read_sigs = [x for x in dict.fromkeys(b_read + i_read) if x not in effective_unreads][-400:]
        merged_unreads = [x for x in dict.fromkeys(list(b_unreads | i_unreads)) if x not in set(i_read)][-200:]
    else:
        effective_unreads = b_unreads - set(b_read)
        read_sigs = [x for x in dict.fromkeys(b_read + i_read) if x not in effective_unreads][-400:]
        merged_unreads = [x for x in dict.fromkeys(list(b_unreads | i_unreads)) if x not in set(b_read)][-200:]

    b_mdel = [str(x) for x in (bp.get("deleted_message_sigs") or []) if str(x)]
    i_mdel = [str(x) for x in (ip.get("deleted_message_sigs") or []) if str(x)]
    msg_del_sigs = list(dict.fromkeys(b_mdel + i_mdel))[-400:]

    b_mread = [str(x) for x in (bp.get("read_message_sigs") or []) if str(x)]
    i_mread = [str(x) for x in (ip.get("read_message_sigs") or []) if str(x)]
    msg_read_sigs = list(dict.fromkeys(b_mread + i_mread))[-400:]

    out = copy.deepcopy(bp)
    for k, v in ip.items():
        if v not in (None, "") or k not in out:
            out[k] = copy.deepcopy(v)
    out["restarted_unix"] = max(b_restart, i_restart)
    out["tutorial_completed"] = tut_done
    out["tutorial_skipped"] = tut_skip
    out["tutorial_reward_claimed"] = tut_rew
    out["tutorial_step"] = tut_step
    out["quests"] = quests
    out["read_report_sigs"] = read_sigs
    out["deleted_report_sigs"] = del_sigs
    out["unread_toggled_sigs"] = merged_unreads
    out["read_message_sigs"] = msg_read_sigs
    out["deleted_message_sigs"] = msg_del_sigs
    return out


def _is_welcome_message(msg: Any) -> bool:
    if not isinstance(msg, dict):
        return False
    subj = str(msg.get("subject", "")).strip().lower()
    frm = str(msg.get("from", msg.get("from_name", ""))).strip().lower()
    return ("hoş geldiniz" in subj or "hos geldiniz" in subj) and ("konsey" in frm or "taht ve kılıç" in frm or "taht ve kilic" in frm)


def _message_sig_str(msg: Any) -> str:
    if not isinstance(msg, dict):
        return ""
    to_n = _norm_p_name(str(msg.get("to", msg.get("to_name", ""))).strip()).lower()
    if _is_welcome_message(msg):
        return f"welcome:{to_n}"
    from_n = _norm_p_name(str(msg.get("from", msg.get("from_name", ""))).strip()).lower()
    subj = str(msg.get("subject", "")).strip().lower()
    ts = int(msg.get("created_unix", 0) or 0)
    return f"{from_n}|{to_n}|{subj}|{ts}"


def _message_sig(msg: Any) -> str:
    return _message_sig_str(msg)


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

    # Güncel oyuncu profilini client'ın state.player'ından player_profiles içine yansıt (monotonik korumalı)
    c_player = c_state.get("player")
    s_profs_src = ((server_w or {}).get("state", {}).get("world", {}).get("player_profiles", {}) or {})
    s_existing_prof: Dict[str, Any] = {}
    if act_name and isinstance(s_profs_src, dict):
        for spk, spv in s_profs_src.items():
            if _matches_player(str(spk), act_name) and isinstance(spv, dict):
                s_existing_prof = spv
                break
    s_last_raw = int((server_w or {}).get("last_saved_unix", 0) or 0)
    c_last_raw = int(c_w.get("last_saved_unix", now) or now)
    c_has_act_village = any(
        _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), act_name)
        for v in (c_state.get("villages") or [])
    )
    if isinstance(c_player, dict) and act_name:
        c_profs = c_w_dict.setdefault("player_profiles", {})
        c_name_matches = _matches_player(str(c_player.get("name", "")), act_name)
        if not c_name_matches and s_existing_prof:
            c_profs[act_name] = copy.deepcopy(s_existing_prof)
        else:
            raw_cd = c_player.get("diamonds")
            c_diamonds = max(0, int(raw_cd)) if raw_cd is not None else max(0, int(s_existing_prof.get("diamonds", STARTER_DIAMONDS)))
            c_scrolls = copy.deepcopy(c_player["scrolls"]) if isinstance(c_player.get("scrolls"), dict) else copy.deepcopy(s_existing_prof.get("scrolls") if isinstance(s_existing_prof.get("scrolls"), dict) else {})
            incoming_prof = {
                "name": act_name,
                "provider": str(c_player.get("provider", s_existing_prof.get("provider", ""))),
                "auth_id": str(c_player.get("auth_id", s_existing_prof.get("auth_id", ""))),
                "points": int(c_player.get("points", s_existing_prof.get("points", 0)) or 0),
                "created_unix": int(c_player.get("created_unix", s_existing_prof.get("created_unix", 0)) or 0),
                "starter_boost_until_unix": int(c_player.get("starter_boost_until_unix", s_existing_prof.get("starter_boost_until_unix", 0)) or 0),
                "protection_until_unix": int(c_player.get("protection_until_unix", s_existing_prof.get("protection_until_unix", 0)) or 0),
                "conquest_protection_until_unix": int(c_player.get("conquest_protection_until_unix", s_existing_prof.get("conquest_protection_until_unix", 0)) or 0),
                "restarted_unix": int(c_player.get("restarted_unix", s_existing_prof.get("restarted_unix", 0)) or 0),
                "tutorial_completed": bool(c_player.get("tutorial_completed", False)),
                "tutorial_skipped": bool(c_player.get("tutorial_skipped", False)),
                "tutorial_step": int(c_player.get("tutorial_step", 0) or 0),
                "tutorial_reward_claimed": bool(c_player.get("tutorial_reward_claimed", False)),
                "quests": copy.deepcopy(c_player.get("quests") if isinstance(c_player.get("quests"), dict) else {"claimed": [], "stats": {}}),
                "gold_armour": int(c_player.get("gold_armour", s_existing_prof.get("gold_armour", 0)) or 0),
                "diamonds": c_diamonds,
                "scrolls": c_scrolls,
                "active_village_id": int(c_state.get("active_village_id", s_existing_prof.get("active_village_id", -1)) or -1),
            }
            if isinstance(c_player.get("read_report_sigs"), list):
                incoming_prof["read_report_sigs"] = [str(x) for x in c_player["read_report_sigs"] if str(x)]
            if isinstance(c_player.get("deleted_report_sigs"), list):
                incoming_prof["deleted_report_sigs"] = [str(x) for x in c_player["deleted_report_sigs"] if str(x)]
            if isinstance(c_player.get("unread_toggled_sigs"), list):
                incoming_prof["unread_toggled_sigs"] = [str(x) for x in c_player["unread_toggled_sigs"] if str(x)]
            if isinstance(c_player.get("read_message_sigs"), list):
                incoming_prof["read_message_sigs"] = [str(x) for x in c_player["read_message_sigs"] if str(x)]
            if isinstance(c_player.get("deleted_message_sigs"), list):
                incoming_prof["deleted_message_sigs"] = [str(x) for x in c_player["deleted_message_sigs"] if str(x)]
            c_profs[act_name] = _merge_player_profile_dicts(
                s_existing_prof,
                incoming_prof,
                c_is_newer=(c_has_act_village and c_last_raw >= s_last_raw),
            )

    if not server_w or not isinstance(server_w.get("state"), dict) or not (server_w["state"].get("villages")):
        merged = copy.deepcopy(c_w)
        merged["last_saved_unix"] = now
        _deduplicate_world_villages(merged, act_name)
        merged["registered_real_players"] = _collect_real_players(merged)
        _rebuild_tiles(merged["state"])
        return merged

    merged = copy.deepcopy(server_w)
    _deduplicate_world_villages(merged)
    s_state = merged.setdefault("state", {})
    s_w_dict = s_state.setdefault("world", {})
    s_last = int(merged.get("last_saved_unix", 0) or 0)
    c_last = int(c_w.get("last_saved_unix", now) or now)

    # 1. Profiller ve başlangıç bonusları (her oyuncunun verisi monotonik şekilde korunur)
    s_profs = s_w_dict.setdefault("player_profiles", {})
    c_profs = c_w_dict.get("player_profiles") if isinstance(c_w_dict.get("player_profiles"), dict) else {}
    for pk, pv in c_profs.items():
        if isinstance(pv, dict) and (_matches_player(pk, act_name) or pk not in s_profs):
            s_profs[pk] = _merge_player_profile_dicts(
                s_profs.get(pk),
                pv,
                c_is_newer=(c_has_act_village and c_last >= s_last),
            )

    s_psb = s_w_dict.setdefault("player_starter_boost", {})
    c_psb = c_w_dict.get("player_starter_boost") if isinstance(c_w_dict.get("player_starter_boost"), dict) else {}
    for bk, bv in c_psb.items():
        if isinstance(bv, dict) and (_matches_player(bk, act_name) or bk not in s_psb):
            s_psb[bk] = copy.deepcopy(bv)

    # 2. Köyleri indeksle ve eşzamanlı yeni köy ID / mesafe çakışmalarını çöz
    s_villages: List[Dict[str, Any]] = [
        copy.deepcopy(v) for v in (s_state.get("villages") or [])
        if isinstance(v, dict) and v.get("id") is not None and int(v.get("id") or 0) > 0
    ]
    c_villages: List[Dict[str, Any]] = [
        copy.deepcopy(v) for v in (c_state.get("villages") or [])
        if isinstance(v, dict) and v.get("id") is not None and int(v.get("id") or 0) > 0
    ]

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
    remapped_preserve_server: set = set()
    stale_conquered_vids = set()
    acting_client_vids_before = {
        int(v.get("id", 0)) for v in c_villages
        if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), act_name)
    }

    # Client'taki aktif oyuncunun köylerini kontrol et: başka bir gerçek oyuncunun köy ID'siyle çakışıyor mu veya çift başlangıç köyü mü?
    act_existing_starter = None
    for sv in s_villages:
        sv_id = int(sv.get("id", 0))
        if _is_real_player_village(sv) and _matches_player(str(sv.get("owner", "")), act_name) and sv_id not in server_conquered_vids:
            act_existing_starter = sv
            break

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
                if act_existing_starter is not None and old_vid not in all_conquered_target_vids:
                    # Sunucuda zaten başlangıç köyü var; ikinci 'Başkent' klonu açmak yerine mevcut kanonik ID'ye eşle!
                    canon_id = int(act_existing_starter["id"])
                    vid_remap[old_vid] = canon_id
                    if int(act_existing_starter.get("points", 110) or 110) > int(c_v.get("points", 110) or 110):
                        remapped_preserve_server.add(canon_id)
                    c_v["id"] = canon_id
                    c_v["x"] = int(act_existing_starter.get("x", c_v.get("x", 100)))
                    c_v["y"] = int(act_existing_starter.get("y", c_v.get("y", 100)))
                    continue
                is_new_starter_or_collision = True
                max_vid += 1
                vid_remap[old_vid] = max_vid
                c_v["id"] = max_vid
                old_vid = max_vid
        elif s_match is None:
            if act_existing_starter is not None and old_vid not in all_conquered_target_vids:
                canon_id = int(act_existing_starter["id"])
                vid_remap[old_vid] = canon_id
                if int(act_existing_starter.get("points", 110) or 110) > int(c_v.get("points", 110) or 110):
                    remapped_preserve_server.add(canon_id)
                c_v["id"] = canon_id
                c_v["x"] = int(act_existing_starter.get("x", c_v.get("x", 100)))
                c_v["y"] = int(act_existing_starter.get("y", c_v.get("y", 100)))
                continue
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
            if vid in remapped_preserve_server and s_v is not None:
                continue
            # Bayat client kaydı veya sunucudaki daha yüksek bina seviyesi / daha yeni köy ismi korunur
            if s_v is not None and isinstance(s_v, dict):
                s_blds = s_v.get("buildings") if isinstance(s_v.get("buildings"), dict) else {}
                c_blds = c_v.get("buildings") if isinstance(c_v.get("buildings"), dict) else {}
                c_teardown = int(c_v.get("teardown_unix", 0) or 0) > int(s_v.get("teardown_unix", 0) or 0)
                if c_last < s_last and not c_teardown and isinstance(s_blds, dict):
                    merged_blds = dict(c_blds)
                    for bk, sv_lvl in s_blds.items():
                        sv_i = int(sv_lvl or 0)
                        cv_i = int(merged_blds.get(bk, 0) or 0)
                        if sv_i > cv_i:
                            merged_blds[bk] = sv_i
                    c_v["buildings"] = merged_blds
                    c_v["points"] = max(int(c_v.get("points", 0) or 0), int(s_v.get("points", 0) or 0))
                s_nu = int(s_v.get("name_updated_unix", 0) or 0)
                c_nu = int(c_v.get("name_updated_unix", 0) or 0)
                s_ns = int(s_v.get("name_edit_seq", 0) or 0)
                c_ns = int(c_v.get("name_edit_seq", 0) or 0)
                if (s_nu > c_nu or (s_nu == c_nu and s_ns > c_ns)) and str(s_v.get("name", "")).strip():
                    c_v["name"] = s_v["name"]
                    c_v["name_updated_unix"] = s_nu
                    c_v["name_edit_seq"] = s_ns
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

            # Aktif oyuncunun bu köye yönelik YENİ savaş veya ticaret raporu varsa kayıpları/hammaddeyi uygula
            for rep in new_client_reports:
                rtype = rep.get("type")
                rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
                if int(rdata.get("target_village_id", 0) or 0) != vid:
                    continue
                if rtype == "battle":
                    for uk, loss in (rdata.get("defender_losses") or {}).items():
                        v_units[uk] = max(0, int(v_units.get(uk, 0) or 0) - int(loss or 0))
                    s_v["units"] = v_units
                    v_res = dict(s_v.get("resources") or {})
                    for rk, loot_v in (rdata.get("loot") or {}).items():
                        v_res[rk] = max(0, int(v_res.get(rk, 0) or 0) - int(loot_v or 0))
                    s_v["resources"] = v_res
                    if "realm_after" in rdata and int(rdata.get("realm_after", -1)) >= 0:
                        s_v["realm_of_power"] = int(rdata["realm_after"])
                elif rtype == "trade":
                    v_res = dict(s_v.get("resources") or {})
                    t_res = rdata.get("resources") if isinstance(rdata.get("resources"), dict) else {}
                    for rk in ("wood", "stone", "iron"):
                        v_res[rk] = int(v_res.get(rk, 0) or 0) + int(t_res.get(rk, 0) or 0)
                    s_v["resources"] = v_res
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

    bot_vids_now = {
        int(v.get("id", 0)) for v in s_state["villages"]
        if isinstance(v, dict) and bool(v.get("is_bot", False))
    }
    # 3. Kuyruklar (queues): aktif oyuncunun kuyrukları client'tan, diğer oyuncularınki server'dan, bot kuyrukları korunur
    merged_queues: List[Dict[str, Any]] = []
    seen_q_sigs = set()
    client_has_bot_q = any(
        isinstance(q, dict) and int(q.get("village_id", 0) or 0) in bot_vids_now
        for q in (c_state.get("queues") or [])
    )
    use_client_bots = client_has_bot_q and c_last >= s_last
    for q in (s_state.get("queues") or []):
        if not isinstance(q, dict):
            continue
        q_vid = int(q.get("village_id", 0) or 0)
        if q_vid in acting_vids_now:
            continue
        if q_vid in bot_vids_now and use_client_bots:
            continue
        q_sig = (q_vid, str(q.get("type", "")), str(q.get("key", "")), int(q.get("finish_unix", 0) or 0))
        if q_sig not in seen_q_sigs:
            seen_q_sigs.add(q_sig)
            merged_queues.append(q)
    for q in (c_state.get("queues") or []):
        if not isinstance(q, dict):
            continue
        qc = copy.deepcopy(q)
        q_vid = int(qc.get("village_id", 0) or 0)
        if q_vid in vid_remap:
            q_vid = vid_remap[q_vid]
            qc["village_id"] = q_vid
        if q_vid in acting_vids_now or (q_vid in bot_vids_now and use_client_bots):
            q_sig = (q_vid, str(qc.get("type", "")), str(qc.get("key", "")), int(qc.get("finish_unix", 0) or 0))
            if q_sig not in seen_q_sigs:
                seen_q_sigs.add(q_sig)
                merged_queues.append(qc)
    s_state["queues"] = merged_queues

    # 4. Hareketler (movements)
    all_acting_vids = acting_vids_now | acting_client_vids_before

    def _is_acting_player_movement(mov: Dict[str, Any]) -> bool:
        m_owner = str(mov.get("owner", "")).strip()
        if m_owner and _matches_player(m_owner, act_name):
            return True
        m_vid = int(mov.get("village_id", 0) or 0)
        if m_vid in all_acting_vids:
            return True
        m_state = str(mov.get("state", "outgoing"))
        m_type = str(mov.get("type", ""))
        is_ret = (m_state == "returning" or m_type == "return")
        fv_raw = int(mov.get("from_village_id", 0) or 0)
        tv_raw = int(mov.get("to_village_id", 0) or 0)
        if is_ret:
            return tv_raw in all_acting_vids
        return fv_raw in all_acting_vids

    # Dönüşe geçmiş (returning) hareketlerin orijinal gidiş ID veya battle_seed değerlerini topla
    returned_origin_ids = set()
    returned_seeds = set()
    for m in (c_state.get("movements") or []):
        if not isinstance(m, dict):
            continue
        if str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return":
            orig_mid = int(m.get("origin_movement_id", 0) or 0)
            if orig_mid > 0:
                returned_origin_ids.add(orig_mid)
            b_seed = int(m.get("battle_seed", 0) or 0)
            if b_seed > 0:
                returned_seeds.add(b_seed)

    merged_movements: List[Dict[str, Any]] = []
    seen_mov = set()
    seen_acting_mov_ids = set()
    # Önce aktif oyuncunun köylerinden çıkan/client'ta bilinen hareketler
    for m in (c_state.get("movements") or []):
        if not isinstance(m, dict):
            continue
        mc = copy.deepcopy(m)
        is_ret = (str(mc.get("state", "")) == "returning" or str(mc.get("type", "")) == "return")
        mid = int(mc.get("id", 0) or 0)
        b_seed = int(mc.get("battle_seed", 0) or 0)
        if not is_ret and ((mid > 0 and mid in returned_origin_ids) or (b_seed > 0 and b_seed in returned_seeds)):
            continue
        fv = int(mc.get("from_village_id", 0) or 0)
        tv = int(mc.get("to_village_id", 0) or 0)
        v_orig = int(mc.get("village_id", 0) or 0)
        if fv in vid_remap:
            mc["from_village_id"] = vid_remap[fv]
        if tv in vid_remap:
            mc["to_village_id"] = vid_remap[tv]
        if v_orig in vid_remap:
            mc["village_id"] = vid_remap[v_orig]
        if mid > 0 and _is_acting_player_movement(mc):
            if (mid, is_ret) in seen_acting_mov_ids:
                continue
            seen_acting_mov_ids.add((mid, is_ret))
        sig = _movement_sig(mc)
        if sig not in seen_mov:
            seen_mov.add(sig)
            merged_movements.append(mc)
    # Diğer gerçek oyuncuların sunucudaki hareketlerini koru (aktif oyuncunun kendi hareketlerinde client %100 otoriterdir)
    for m in (s_state.get("movements") or []):
        if not isinstance(m, dict):
            continue
        if _is_acting_player_movement(m):
            continue
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

    act_prof_final: Dict[str, Any] = {}
    for pk, pv in s_profs.items():
        if _matches_player(str(pk), act_name) and isinstance(pv, dict):
            act_prof_final = pv
            break
    act_read_sigs = {str(x) for x in (act_prof_final.get("read_report_sigs") or []) if str(x)}
    act_del_sigs = {str(x) for x in (act_prof_final.get("deleted_report_sigs") or []) if str(x)}
    act_read_msg_sigs = {str(x) for x in (act_prof_final.get("read_message_sigs") or []) if str(x)}
    act_del_msg_sigs = {str(x) for x in (act_prof_final.get("deleted_message_sigs") or []) if str(x)}

    # 6. Mesajlar ve Raporlar (kanonik imzalı deduplicated union + kalıcı okunma/silme)
    s_msgs: List[Dict[str, Any]] = []
    msg_idx: Dict[str, int] = {}
    for raw_m in (s_state.get("messages") or []) + (c_state.get("messages") or []):
        if not isinstance(raw_m, dict):
            continue
        mc = copy.deepcopy(raw_m)
        msig = _message_sig_str(mc)
        to_n = str(mc.get("to", mc.get("to_name", ""))).strip()
        from_n = str(mc.get("from", mc.get("from_name", ""))).strip()
        is_to_act = _matches_player(to_n, act_name)
        is_from_act = _matches_player(from_n, act_name)
        if msig in act_read_msg_sigs and (is_to_act or is_from_act):
            mc["read"] = True
        if msig not in msg_idx:
            msg_idx[msig] = len(s_msgs)
            s_msgs.append(mc)
        else:
            existing_m = s_msgs[msg_idx[msig]]
            if bool(mc.get("read", False)) or (msig in act_read_msg_sigs and (is_to_act or is_from_act)):
                existing_m["read"] = True

    cleaned_msgs: List[Dict[str, Any]] = []
    for m in s_msgs:
        msig = _message_sig_str(m)
        to_n = str(m.get("to", m.get("to_name", ""))).strip()
        from_n = str(m.get("from", m.get("from_name", ""))).strip()
        if msig in act_del_msg_sigs and _matches_player(to_n, act_name) and (_is_welcome_message(m) or _matches_player(from_n, act_name) or from_n not in _collect_real_players(merged)):
            continue
        cleaned_msgs.append(m)
    s_state["messages"] = cleaned_msgs[-250:]

    s_reps = list(s_state.get("reports") or [])
    rep_idx_by_sig: Dict[tuple, int] = {}
    for idx, sr in enumerate(s_reps):
        if isinstance(sr, dict):
            rep_idx_by_sig[_report_sig(sr)] = idx
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
        rsig_str = _report_sig_str(rc)
        if rsig not in rep_idx_by_sig:
            rep_idx_by_sig[rsig] = len(s_reps)
            if rsig_str in act_read_sigs:
                rc["unread"] = False
            s_reps.append(rc)
        else:
            existing_rep = s_reps[rep_idx_by_sig[rsig]]
            rep_vid = int(existing_rep.get("village_id", 0) or 0)
            if rep_vid in acting_vids_now or rsig_str in act_read_sigs:
                if rsig_str in act_read_sigs:
                    existing_rep["unread"] = False
                elif c_has_act_village and c_last >= s_last and "unread" in rc:
                    existing_rep["unread"] = bool(rc.get("unread", False))
    for rep in s_reps:
        if isinstance(rep, dict) and _report_sig_str(rep) in act_read_sigs:
            rep["unread"] = False
    # Yalnızca aktif oyuncuya ait olup silinmiş raporları kanonik listeden de temizle (ortak çoklu oyuncu raporları diğer oyuncuda kalır, _prepare_world_for_player gizler)
    cleaned_reps: List[Dict[str, Any]] = []
    for rep in s_reps:
        if not isinstance(rep, dict):
            continue
        if _report_sig_str(rep) in act_del_sigs:
            rep_vid = int(rep.get("village_id", 0) or 0)
            rdata = rep.get("data") if isinstance(rep.get("data"), dict) else {}
            t_vid = int(rdata.get("target_village_id", 0) or 0)
            t_v = s_by_id.get(t_vid) if t_vid > 0 else None
            shared_with_other_human = (
                t_v is not None
                and _is_real_player_village(t_v)
                and not _matches_player(str(t_v.get("owner", "")), act_name)
            )
            if rep_vid in acting_vids_now and not shared_with_other_human:
                continue
        cleaned_reps.append(rep)
    s_state["reports"] = cleaned_reps[-250:]

    # 7. Dünya meta & kayıtlı oyuncular & tek başlangıç köyü denetimi
    _deduplicate_world_villages(merged, act_name)
    merged["last_saved_unix"] = now
    s_w_dict["last_saved_unix"] = now
    s_w_dict["sim_now_unix"] = max(int(s_w_dict.get("sim_now_unix", 0) or 0), int(c_w_dict.get("sim_now_unix", now) or now), now)
    merged["registered_real_players"] = _collect_real_players(merged)
    return merged


def ensure_cloud_saves_table(cursor, is_pg: bool) -> None:
    global _PG_SCHEMA_INITIALIZED
    if is_pg and _PG_SCHEMA_INITIALIZED:
        return
    if is_pg:
        cursor.execute(
            "SELECT to_regclass('public.world_states') AS ws, to_regclass('public.cloud_saves') AS cs, to_regclass('public.server_meta') AS sm, to_regclass('public.oauth_sessions') AS oa, to_regclass('public.iap_transactions') AS iap"
        )
        trow = cursor.fetchone()
        if trow and all(trow.get(k) is not None for k in ("ws", "cs", "sm", "oa", "iap")):
            _ensure_users_store_columns(cursor, True)
            _PG_SCHEMA_INITIALIZED = True
            return
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
    cursor.execute("""CREATE TABLE IF NOT EXISTS server_meta (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
    )""")
    cursor.execute("""CREATE TABLE IF NOT EXISTS oauth_sessions (
        session_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        provider TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_unix {0} NOT NULL
    )""".format(bigint_t))
    cursor.execute("""CREATE TABLE IF NOT EXISTS iap_transactions (
        transaction_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        pack_id TEXT NOT NULL,
        diamonds_added INTEGER NOT NULL,
        platform TEXT NOT NULL DEFAULT 'ios',
        receipt_data TEXT DEFAULT '',
        created_unix {0} NOT NULL
    )""".format(bigint_t))
    _ensure_users_store_columns(cursor, is_pg)
    if is_pg:
        _PG_SCHEMA_INITIALIZED = True


def _ensure_world_reset_epoch(cursor, now: int) -> None:
    global _PG_EPOCH_VERIFIED
    if getattr(cursor, "is_pg", False) and _PG_EPOCH_VERIFIED:
        return
    cursor.execute("SELECT v FROM server_meta WHERE k = ?", ("world_reset_epoch",))
    row = cursor.fetchone()
    current_epoch = 0
    if row:
        try:
            raw_v = row["v"] if isinstance(row, dict) else row[0]
            current_epoch = int(str(raw_v) or 0)
        except Exception:
            current_epoch = 0
    if current_epoch >= WORLD_RESET_EPOCH:
        if getattr(cursor, "is_pg", False):
            _PG_EPOCH_VERIFIED = True
        return
    for tbl in (
        "cloud_saves",
        "world_states",
        "movements",
        "queues",
        "reports",
        "messages",
        "alliance_invitations",
        "alliance_members",
        "alliances",
        "villages",
        "users",
        "worlds",
    ):
        cursor.execute(f"DELETE FROM {tbl}")
    _ensure_worlds_rows(cursor, now)
    _ensure_world1_bots_seeded(cursor, now)
    val_str = str(WORLD_RESET_EPOCH)
    if row:
        cursor.execute("UPDATE server_meta SET v = ? WHERE k = ?", (val_str, "world_reset_epoch"))
    else:
        cursor.execute("INSERT INTO server_meta (k, v) VALUES (?, ?)", ("world_reset_epoch", val_str))


def _sync_worlds_table_from_states(cursor, now: int, ws_rows: Optional[List[Any]] = None, write_updates: bool = True) -> List[Dict[str, Any]]:
    _ensure_worlds_rows(cursor, now)
    if ws_rows is None:
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

    cursor.execute("SELECT * FROM worlds ORDER BY id ASC")
    rows = cursor.fetchall()
    existing_by_id = {int(r["id"]): dict(r) for r in rows}

    if write_updates:
        unlocked_ids = set()
        for wid in range(1, WORLDS_COUNT + 1):
            cnt = reg_counts.get(wid, None)
            if cnt is None:
                continue
            cur_row = existing_by_id.get(wid)
            if cur_row and int(cur_row.get("registered_players", 0) or 0) != cnt:
                cursor.execute("UPDATE worlds SET registered_players = ? WHERE id = ?", (cnt, wid))
                cur_row["registered_players"] = cnt
            if cnt >= MAX_REAL_PLAYERS_PER_WORLD and wid < WORLDS_COUNT:
                next_row = existing_by_id.get(wid + 1)
                if next_row and int(next_row.get("is_active", 0) or 0) != 1 and (wid + 1) not in unlocked_ids:
                    unlocked_ids.add(wid + 1)
                    cursor.execute("UPDATE worlds SET is_active = 1 WHERE id = ?", (wid + 1,))
                    next_row["is_active"] = 1

    out: List[Dict[str, Any]] = []
    for wid in sorted(existing_by_id.keys()):
        d = existing_by_id[wid]
        if wid in reg_counts:
            d["registered_players"] = reg_counts[wid]
        out.append(d)
    return out


def _migrate_legacy_cloud_saves_to_world_states(cursor, now: int) -> None:
    global _PG_LEGACY_MIGRATED
    if getattr(cursor, "is_pg", False) and _PG_LEGACY_MIGRATED:
        return
    cursor.execute("SELECT COUNT(*) as cnt FROM world_states")
    c_row = cursor.fetchone()
    if c_row and int(list(c_row.values())[0] or 0) > 0:
        if getattr(cursor, "is_pg", False):
            _PG_LEGACY_MIGRATED = True
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


def _fetch_cloud_and_village_with_worlds(cursor, user_id: str, display_name: str, run_bot_sim: bool = False, user_row: Optional[Dict[str, Any]] = None):
    now = int(time.time())
    _ensure_world1_bots_seeded(cursor, now)
    _migrate_legacy_cloud_saves_to_world_states(cursor, now)

    cursor.execute("SELECT world_id, state_json, updated_unix FROM world_states ORDER BY world_id ASC")
    ws_rows = cursor.fetchall()
    if run_bot_sim:
        for row in ws_rows:
            if int(row["world_id"]) == 1:
                try:
                    w1 = json.loads(row["state_json"])
                    if _simulate_server_bots(w1, cursor, now):
                        new_js = json.dumps(w1, ensure_ascii=False)
                        cursor.execute("UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = 1", (new_js, now))
                        row["state_json"] = new_js
                except Exception:
                    pass

    worlds_meta = _sync_worlds_table_from_states(cursor, now, ws_rows=ws_rows, write_updates=False)

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

    if chosen_w is not None and _deduplicate_world_villages(chosen_w):
        try:
            wid_clean = int(chosen_w.get("world_id", 1) or 1)
            cursor.execute(
                "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                (json.dumps(chosen_w, ensure_ascii=False), now, wid_clean)
            )
            cursor.execute("DELETE FROM villages WHERE id IS NULL OR id <= 0")
        except Exception:
            pass

    cursor.execute("SELECT * FROM villages WHERE LOWER(owner) = LOWER(?) AND is_bot = 0 ORDER BY id ASC LIMIT 1", (display_name,))
    v_row = cursor.fetchone()
    server_village = _serialize_server_village(v_row)

    # SQL villages tablosunda köyü olup world_states JSON'ından düşmüşse ortak dünyayı kendi kendine iyileştir
    if server_village is not None:
        sv_wid = int(server_village.get("world_id", 1) or 1)
        if chosen_w is None or int(chosen_w.get("world_id", 1) or 1) != sv_wid:
            for row in ws_rows:
                if int(row["world_id"]) == sv_wid:
                    try:
                        chosen_w = json.loads(row["state_json"])
                        chosen_updated = int(row["updated_unix"] or 0)
                    except Exception:
                        pass
                    break
        if chosen_w is not None and not _player_has_village_in_world(chosen_w, display_name):
            st_heal = chosen_w.setdefault("state", {})
            wd_heal = st_heal.setdefault("world", {})
            vills_heal = st_heal.setdefault("villages", [])
            sv_id = int(server_village.get("id", 51) or 51)
            sv_x = int(server_village.get("x", 100) or 100)
            sv_y = int(server_village.get("y", 100) or 100)
            healed_v = {
                "id": sv_id,
                "name": str(server_village.get("name") or "Başkent"),
                "x": sv_x,
                "y": sv_y,
                "owner": display_name,
                "points": int(server_village.get("points", 110) or 110),
                "is_bot": False,
                "is_barbarian": False,
                "buildings": copy.deepcopy(server_village.get("buildings") or {"main": 1, "farm": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "wall": 0, "hide": 1}),
                "resources": copy.deepcopy(server_village.get("resources") or {"wood": 500, "stone": 500, "iron": 500}),
                "units": copy.deepcopy(server_village.get("units") or {"spear": 0, "sword": 0}),
                "protection_until_unix": int(server_village.get("protection_until_unix", 0) or 0),
                "conquest_protection_until_unix": int(server_village.get("conquest_protection_until_unix", 0) or 0),
                "realm_of_power": 100,
                "loyalty": 100,
            }
            vills_heal[:] = [vv for vv in vills_heal if not (isinstance(vv, dict) and int(vv.get("id", -1) or -1) == sv_id)]
            vills_heal.append(healed_v)
            profs_heal = wd_heal.get("player_profiles")
            if isinstance(profs_heal, dict):
                for pk, pv in profs_heal.items():
                    if _matches_player(pk, display_name) and isinstance(pv, dict):
                        pv.pop("defeated_info", None)
                        pv["active_village_id"] = sv_id
            _rebuild_tiles(st_heal)
            chosen_w["registered_real_players"] = _collect_real_players(chosen_w)
            chosen_w["last_saved_unix"] = now
            chosen_updated = now
            try:
                cursor.execute(
                    "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                    (json.dumps(chosen_w, ensure_ascii=False), now, sv_wid)
                )
                worlds_meta = _sync_worlds_table_from_states(cursor, now, write_updates=True)
            except Exception:
                pass

    if user_row is None:
        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user_id,))
        u_wallet_row = cursor.fetchone()
    else:
        u_wallet_row = user_row
    u_diamonds, u_scrolls = _parse_user_wallet(u_wallet_row)
    user_wallet = {"diamonds": u_diamonds, "scrolls": u_scrolls}

    cloud_state = _prepare_world_for_player(chosen_w, display_name, user_wallet) if chosen_w is not None else None
    if cloud_state is None:
        cursor.execute("SELECT state_json, updated_unix FROM cloud_saves WHERE user_id = ?", (user_id,))
        c_row = cursor.fetchone()
        if c_row:
            chosen_updated = int(c_row["updated_unix"])
            try:
                cloud_state = json.loads(c_row["state_json"])
            except Exception:
                cloud_state = None

    return cloud_state, chosen_updated, server_village, worlds_meta


def _fetch_cloud_and_village(cursor, user_id: str, display_name: str, user_row: Optional[Dict[str, Any]] = None):
    cs, cu, sv, _wm = _fetch_cloud_and_village_with_worlds(cursor, user_id, display_name, False, user_row)
    return cs, cu, sv


def _decode_jwt_claims_unverified(token: str) -> Dict[str, Any]:
    tok = (token or "").strip()
    if not tok or "." not in tok:
        return {}
    parts = tok.split(".")
    if len(parts) < 2:
        return {}
    try:
        import base64
        seg = parts[1].replace("-", "+").replace("_", "/")
        pad = (-len(seg)) % 4
        if pad:
            seg += "=" * pad
        raw = base64.b64decode(seg)
        obj = json.loads(raw.decode("utf-8"))
        return obj if isinstance(obj, dict) else {}
    except Exception:
        return {}


def _find_user_by_identity(cursor, provider: str, clean_email: str, clean_uid: str, identity_token: str = ""):
    claims = _decode_jwt_claims_unverified(identity_token)
    jwt_sub = str(claims.get("sub") or "").strip()
    jwt_email = str(claims.get("email") or "").strip().lower()

    uid_candidates = []
    for cand in (clean_uid, jwt_sub):
        if cand and cand not in uid_candidates:
            uid_candidates.append(cand)

    email_candidates = []
    for cand in (clean_email, jwt_email):
        if cand and "@" in cand and cand not in email_candidates:
            email_candidates.append(cand)

    uid_id_candidates: List[str] = []
    for uid in uid_candidates:
        h12 = f"{provider}_{hashlib.sha256(f'{provider}:{uid}'.encode('utf-8')).hexdigest()[:12]}"
        h14 = f"{provider}_{hashlib.sha256(f'{provider}:{uid}'.encode('utf-8')).hexdigest()[:14]}"
        for id_cand in (h12, h14, uid):
            if id_cand not in uid_id_candidates:
                uid_id_candidates.append(id_cand)

    em_id_candidates: List[str] = []
    for em in email_candidates:
        em_h12 = f"{provider}_{hashlib.sha256(f'{provider}:{em}'.encode('utf-8')).hexdigest()[:12]}"
        em_h14 = f"{provider}_{hashlib.sha256(f'{provider}:{em}'.encode('utf-8')).hexdigest()[:14]}"
        for id_cand in (em_h12, em_h14):
            if id_cand not in em_id_candidates:
                em_id_candidates.append(id_cand)

    all_ids: List[str] = list(dict.fromkeys(uid_id_candidates + em_id_candidates))
    conds: List[str] = []
    params: List[Any] = []
    if uid_candidates:
        conds.append(f"(provider = ? AND provider_uid IN ({','.join(['?'] * len(uid_candidates))}))")
        params.append(provider)
        params.extend(uid_candidates)
    if all_ids:
        conds.append(f"id IN ({','.join(['?'] * len(all_ids))})")
        params.extend(all_ids)
    if email_candidates:
        conds.append(f"(provider = ? AND LOWER(email) IN ({','.join(['?'] * len(email_candidates))}))")
        params.append(provider)
        params.extend(email_candidates)

    if conds:
        cursor.execute(f"SELECT * FROM users WHERE {' OR '.join(conds)}", tuple(params))
        rows = cursor.fetchall()
        if rows:
            for uid in uid_candidates:
                for r in rows:
                    if str(r.get("provider") or "") == provider and str(r.get("provider_uid") or "") == uid:
                        return r, uid, (email_candidates[0] if email_candidates else "")
            for uid in uid_candidates:
                h12 = f"{provider}_{hashlib.sha256(f'{provider}:{uid}'.encode('utf-8')).hexdigest()[:12]}"
                h14 = f"{provider}_{hashlib.sha256(f'{provider}:{uid}'.encode('utf-8')).hexdigest()[:14]}"
                for id_cand in (h12, h14, uid):
                    for r in rows:
                        if str(r.get("id") or "") == id_cand:
                            return r, uid, (email_candidates[0] if email_candidates else "")
            for em in email_candidates:
                for r in rows:
                    if str(r.get("provider") or "") == provider and str(r.get("email") or "").strip().lower() == em:
                        return r, (uid_candidates[0] if uid_candidates else ""), em
            for em in email_candidates:
                em_h12 = f"{provider}_{hashlib.sha256(f'{provider}:{em}'.encode('utf-8')).hexdigest()[:12]}"
                em_h14 = f"{provider}_{hashlib.sha256(f'{provider}:{em}'.encode('utf-8')).hexdigest()[:14]}"
                for id_cand in (em_h12, em_h14):
                    for r in rows:
                        if str(r.get("id") or "") == id_cand:
                            return r, (uid_candidates[0] if uid_candidates else ""), em

    return None, (uid_candidates[0] if uid_candidates else ""), (email_candidates[0] if email_candidates else "")


def _name_variants(raw_name: str) -> set:
    norm = normalize_display_name(raw_name) or ""
    if not norm:
        return set()
    bare = norm[5:].strip() if norm.lower().startswith("lord ") else norm
    variants = {norm.lower()}
    if bare:
        variants.add(bare.lower())
        variants.add(f"lord {bare.lower()}")
    return variants


def _is_display_name_taken(cursor, display_name: str, exclude_user_id: Optional[str] = None) -> bool:
    wanted = _name_variants(display_name)
    if not wanted:
        return True

    # 1. Bot isimleri ayrılmıştır
    for bname in WORLD1_BOT_NAMES:
        if _name_variants(bname) & wanted:
            return True

    # 2. Kayıtlı diğer oyuncular
    cursor.execute("SELECT id, display_name FROM users")
    exclude_name = ""
    for u in cursor.fetchall():
        uid_s = str(u["id"])
        u_dname = str(u["display_name"] or "")
        if exclude_user_id and uid_s == str(exclude_user_id):
            exclude_name = u_dname
            continue
        if _name_variants(u_dname) & wanted:
            return True

    # 3. Köyler tablosundaki gerçek oyuncular ve botlar
    cursor.execute("SELECT user_id, owner, is_bot FROM villages WHERE is_barbarian = 0")
    for vr in cursor.fetchall():
        vr_d = dict(vr)
        if exclude_user_id and vr_d.get("user_id") and str(vr_d["user_id"]) == str(exclude_user_id):
            continue
        if _name_variants(str(vr_d.get("owner") or "")) & wanted:
            return True

    # 4. Ortak dünya durumlarındaki kayıtlı gerçek oyuncular
    cursor.execute("SELECT state_json FROM world_states")
    for ws in cursor.fetchall():
        try:
            wd = json.loads(ws["state_json"])
            for rp in _collect_real_players(wd):
                if exclude_name and _matches_player(rp, exclude_name):
                    continue
                if _name_variants(rp) & wanted:
                    return True
        except Exception:
            pass
    return False


@app.post("/api/auth/check_account")
def auth_check_account(req: CheckAccountRequest):
    now = int(time.time())
    provider = (req.provider or "google").strip().lower()
    if provider not in ("google", "apple"):
        provider = "google"
    clean_email = (req.email or "").strip().lower()
    clean_uid = (req.provider_uid or "").strip()
    raw_id_tok = (req.identity_token or "").strip()

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)

        existing, resolved_uid, resolved_email = _find_user_by_identity(cursor, provider, clean_email, clean_uid, raw_id_tok)

        if not existing:
            return {"ok": True, "exists": False}

        user_id = existing["id"]
        display_name = existing["display_name"]
        existing_d = dict(existing)
        email = existing_d.get("email") or resolved_email or clean_email
        stored_puid = str(existing_d.get("provider_uid") or "").strip() or resolved_uid
        created_unix = int(existing["created_unix"] or now)

        cloud_state, cloud_updated_unix, server_village, worlds_meta = _fetch_cloud_and_village_with_worlds(cursor, user_id, display_name, False, existing_d)
        has_village = bool(server_village is not None or _player_has_village_in_world(cloud_state, display_name))
        u_diamonds, u_scrolls = _parse_user_wallet(existing_d)

        existing_tok = str(existing_d.get("token") or "").strip()
        token = f"tk_tok_{secrets.token_hex(24)}"
        if conn.is_pg:
            cursor.execute("SAVEPOINT sp_tok_upd")
        try:
            cursor.execute(
                "UPDATE users SET token = ?, last_login_unix = ?, provider_uid = ?, email = ? WHERE id = ?",
                (token, now, stored_puid, email, user_id)
            )
            if conn.is_pg:
                cursor.execute("RELEASE SAVEPOINT sp_tok_upd")
        except Exception:
            if conn.is_pg:
                cursor.execute("ROLLBACK TO SAVEPOINT sp_tok_upd")
            if existing_tok.startswith("tk_tok_"):
                token = existing_tok
            else:
                raise

    return {
        "ok": True,
        "exists": True,
        "token": token,
        "user_id": user_id,
        "provider": provider,
        "email": email,
        "provider_uid": stored_puid,
        "display_name": display_name,
        "created_unix": created_unix,
        "starter_boost_until_unix": created_unix + STARTER_BOOST_SECONDS,
        "has_village": has_village,
        "diamonds": u_diamonds,
        "scrolls": u_scrolls,
        "cloud_state": cloud_state,
        "worlds_meta": worlds_meta,
        "updated_unix": cloud_updated_unix,
        "server_village": server_village,
    }


@app.post("/api/auth/login")
def auth_login(req: AuthLoginRequest):
    display_name = normalize_display_name(req.display_name)
    if not display_name:
        return JSONResponse(status_code=400, content={"ok": False, "error_code": "INVALID_NAME", "detail": "Geçersiz Lord ismi."})

    now = int(time.time())
    provider = (req.provider or "google").strip().lower()
    if provider not in ("google", "apple"):
        provider = "google"

    clean_email = (req.email or "").strip().lower()
    clean_uid = (req.provider_uid or "").strip()
    raw_id_tok = (req.identity_token or "").strip()

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)

        existing, resolved_uid, resolved_email = _find_user_by_identity(cursor, provider, clean_email, clean_uid, raw_id_tok)
        eff_uid = resolved_uid or clean_uid
        eff_email = resolved_email or clean_email
        has_explicit_identity = bool(eff_email or eff_uid)

        uid_seed = f"{provider}:{eff_uid}" if eff_uid else (f"{provider}:{eff_email}" if eff_email else f"{provider}:{display_name.lower()}")
        det_hash = hashlib.sha256(uid_seed.encode("utf-8")).hexdigest()[:12]
        user_id = f"{provider}_{det_hash}"
        token = f"tk_tok_{secrets.token_hex(24)}"
        email = eff_email or f"{display_name.lower().replace(' ', '.')}@{provider}.com"

        bare_name = display_name[5:].strip() if display_name.startswith("Lord ") else display_name
        candidates = [display_name]
        if bare_name and bare_name != display_name:
            candidates.append(bare_name)

        if has_explicit_identity:
            exclude_uid = existing["id"] if existing else user_id
            if _is_display_name_taken(cursor, display_name, exclude_user_id=exclude_uid):
                return JSONResponse(
                    status_code=409,
                    content={
                        "ok": False,
                        "error_code": "NAME_TAKEN",
                        "detail": "Bu Lord ismi daha önce alınmış! Lütfen başka bir Lord ismi seçin.",
                    },
                )
        else:
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
            existing_d = dict(existing)
            user_id = existing["id"]
            if not has_explicit_identity:
                display_name = existing["display_name"]
            elif existing["display_name"] != display_name:
                cursor.execute("UPDATE users SET display_name = ? WHERE id = ?", (display_name, user_id))
            email = existing_d.get("email") or email
            stored_puid = str(existing_d.get("provider_uid") or "").strip() or eff_uid
            created_unix = int(existing["created_unix"] or now)
            cursor.execute(
                "UPDATE users SET token = ?, last_login_unix = ?, provider = ?, provider_uid = ?, email = ? WHERE id = ?",
                (token, now, provider, stored_puid, email, user_id)
            )
        else:
            cursor.execute("""
                INSERT INTO users (id, provider, email, provider_uid, display_name, token, created_unix, last_login_unix, diamonds, scrolls_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (user_id, provider, email, eff_uid, display_name, token, now, now, STARTER_DIAMONDS, "{}"))

        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user_id,))
        u_wallet_row = cursor.fetchone()
        u_diamonds, u_scrolls = _parse_user_wallet(u_wallet_row)

        cloud_state, cloud_updated_unix, server_village, worlds_meta = _fetch_cloud_and_village_with_worlds(cursor, user_id, display_name, False, u_wallet_row)
        has_village = bool(server_village is not None or _player_has_village_in_world(cloud_state, display_name))

    return {
        "ok": True,
        "token": token,
        "user_id": user_id,
        "provider": provider,
        "email": email,
        "provider_uid": eff_uid,
        "display_name": display_name,
        "created_unix": created_unix,
        "starter_boost_until_unix": created_unix + STARTER_BOOST_SECONDS,
        "has_village": has_village,
        "diamonds": u_diamonds,
        "scrolls": u_scrolls,
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
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)
        _migrate_legacy_cloud_saves_to_world_states(cursor, now)
        worlds = _sync_worlds_table_from_states(cursor, now, write_updates=False)
    return {"ok": True, "worlds": worlds}

@app.post("/api/worlds/join")
def join_world(req: JoinWorldRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    p_name = user["display_name"]
    conn = get_db()
    with conn:
        cursor = conn.cursor()

        # Zaten köyü var mı?
        cursor.execute("SELECT * FROM villages WHERE world_id = ? AND LOWER(owner) = LOWER(?) AND is_bot = 0", (req.world_id, p_name))
        existing = cursor.fetchone()
        if existing:
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
        cursor.execute("SELECT subject FROM messages WHERE world_id = ? AND LOWER(to_name) = LOWER(?)", (req.world_id, p_name))
        existing_msgs = cursor.fetchall()
        already_welcomed_sql = any(
            _is_welcome_message({"from": "Taht ve Kılıç Konseyi", "subject": r.get("subject", "")})
            for r in existing_msgs
        )
        if not already_welcomed_sql:
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

    return {"ok": True, "village_id": new_vid, "x": spot[0], "y": spot[1]}

@app.get("/api/worlds/{world_id}/map")
def get_world_map(world_id: int):
    now = int(time.time())
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)
        if world_id == 1:
            _ensure_world1_bots_seeded(cursor, now)
        cursor.execute("""
            SELECT v.id, v.name, v.x, v.y, v.owner, v.points, v.is_bot, v.is_barbarian,
                   v.protection_until_unix, a.tag as alliance_tag
            FROM villages v
            LEFT JOIN alliance_members m ON m.user_name = v.owner
            LEFT JOIN alliances a ON a.id = m.alliance_id
            WHERE v.world_id = ?
        """, (world_id,))
        rows = cursor.fetchall()
    return {"ok": True, "villages": [dict(r) for r in rows]}

@app.get("/api/villages/{village_id}")
def get_village(village_id: int, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM villages WHERE id = ?", (village_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Köy bulunamadı.")

        v_dict = dict(row)
        # Lazy simülasyon
        v_dict = simulate_village_lazy(v_dict, now, conn)

        # Aktif kuyrukları getir
        cursor.execute("SELECT * FROM queues WHERE village_id = ? ORDER BY finish_unix ASC", (village_id,))
        q_rows = cursor.fetchall()

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
    duration = max(15, int(round((dist * 60) / (speed * MARCH_SPEED_BOOST)))) # Alan başına 60 sn / 1.5x hızlandırılmış yürüyüş
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
    with conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM messages WHERE to_name = ? ORDER BY created_unix DESC LIMIT 50
        """, (user["display_name"],))
        rows = cursor.fetchall()
    return {"ok": True, "messages": [dict(r) for r in rows]}

@app.get("/api/messages/sent")
def get_sent(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM messages WHERE from_name = ? ORDER BY created_unix DESC LIMIT 50
        """, (user["display_name"],))
        rows = cursor.fetchall()
    return {"ok": True, "messages": [dict(r) for r in rows]}

@app.post("/api/messages/send")
def send_message(req: SendMessageRequest, user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    clean_to = html.escape(req.to_name.strip())
    clean_subj = html.escape(req.subject.strip())
    clean_body = html.escape(req.body.strip())

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO messages (world_id, from_name, to_name, subject, body, created_unix, is_read)
            VALUES (1, ?, ?, ?, ?, ?, 0)
        """, (user["display_name"], clean_to, clean_subj, clean_body, now))

    return {"ok": True, "sent_unix": now}

@app.get("/api/game/state")
def get_cloud_state(user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)
        cloud_state, cloud_updated_unix, server_village, worlds_meta = _fetch_cloud_and_village_with_worlds(
            cursor, user["id"], user["display_name"], False, user
        )
        u_diamonds, u_scrolls = _parse_user_wallet(user)
    if cloud_state is not None:
        return {
            "ok": True,
            "has_save": True,
            "diamonds": u_diamonds,
            "scrolls": u_scrolls,
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
            "diamonds": u_diamonds,
            "scrolls": u_scrolls,
            "state": None,
            "cloud_state": None,
            "worlds_meta": worlds_meta,
            "server_village": server_village,
            "updated_unix": int(server_village.get("last_calc_unix", 0))
        }
    return {"ok": True, "has_save": False, "diamonds": u_diamonds, "scrolls": u_scrolls, "state": None, "cloud_state": None, "worlds_meta": worlds_meta, "server_village": None, "updated_unix": 0}


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
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        _ensure_world_reset_epoch(cursor, now)
        _migrate_legacy_cloud_saves_to_world_states(cursor, now)

        cursor.execute("SELECT state_json FROM world_states WHERE world_id = ?", (w_id,))
        ws_row = cursor.fetchone()
        server_w = None
        if ws_row:
            try:
                server_w = json.loads(ws_row["state_json"])
            except Exception:
                server_w = None

        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user["id"],))
        u_w_row = cursor.fetchone()
        db_diamonds, db_scrolls = _parse_user_wallet(dict(u_w_row) if u_w_row else user)
        prev_diamonds = db_diamonds
        prev_scrolls = dict(db_scrolls)

        # Eğer client açıkça wallet_authoritative gönderdiyse ve değerler gerçekten değiştiyse senkronla;
        # aksi halde gereksiz `users` satır kilidini önle ve yetkili cüzdanı koru.
        raw_c_player = (
            state_obj.get("state", {}).get("player")
            if isinstance(state_obj.get("state"), dict)
            else state_obj.get("player")
        )
        wallet_auth = bool(payload.get("wallet_authoritative", False) or state_obj.get("wallet_authoritative", False))
        if isinstance(raw_c_player, dict):
            if wallet_auth:
                if raw_c_player.get("diamonds") is not None:
                    db_diamonds = max(0, int(raw_c_player.get("diamonds", db_diamonds)))
                if isinstance(raw_c_player.get("scrolls"), dict):
                    db_scrolls = {
                        str(k): max(0, int(v or 0))
                        for k, v in raw_c_player["scrolls"].items()
                        if int(v or 0) > 0
                    }
                if db_diamonds != prev_diamonds or db_scrolls != prev_scrolls:
                    cursor.execute(
                        "UPDATE users SET diamonds = ?, scrolls_json = ? WHERE id = ?",
                        (db_diamonds, json.dumps(db_scrolls, ensure_ascii=False), user["id"]),
                    )

        merged_w = merge_world_state(server_w, state_obj, user["display_name"], now)
        auth_wallet = {"diamonds": db_diamonds, "scrolls": db_scrolls}
        merged_for_player = _prepare_world_for_player(merged_w, user["display_name"], auth_wallet)
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

        # Oyuncunun birincil köyünü SQL villages tablosu ile senkron tut ki world_states ve villages asla ayrışmasın
        m_vills = (merged_w.get("state") or {}).get("villages") or []
        act_primary_v = None
        for mv in m_vills:
            if _is_real_player_village(mv) and _matches_player(str(mv.get("owner", "")), user["display_name"]):
                act_primary_v = mv
                break
        if isinstance(act_primary_v, dict) and int(act_primary_v.get("id", 0) or 0) > 0:
            pv_id = int(act_primary_v["id"])
            pv_name = str(act_primary_v.get("name") or "Başkent")[:40]
            pv_x = int(act_primary_v.get("x", 100) or 100)
            pv_y = int(act_primary_v.get("y", 100) or 100)
            pv_pts = int(act_primary_v.get("points", 110) or 110)
            pv_blds = json.dumps(act_primary_v.get("buildings") or {}, ensure_ascii=False)
            pv_res = json.dumps(act_primary_v.get("resources") or {}, ensure_ascii=False)
            pv_units = json.dumps(act_primary_v.get("units") or {}, ensure_ascii=False)
            pv_prot = int(act_primary_v.get("protection_until_unix", 0) or 0)
            pv_cprot = int(act_primary_v.get("conquest_protection_until_unix", 0) or 0)
            cursor.execute("SELECT id, is_bot FROM villages WHERE id = ?", (pv_id,))
            v_exist = cursor.fetchone()
            if v_exist and int(v_exist["is_bot"] or 0) == 0:
                cursor.execute("""
                    UPDATE villages
                    SET world_id = ?, user_id = ?, name = ?, x = ?, y = ?, owner = ?, points = ?,
                        buildings_json = ?, resources_json = ?, units_json = ?, last_calc_unix = ?,
                        protection_until_unix = ?, conquest_protection_until_unix = ?
                    WHERE id = ? AND is_bot = 0
                """, (w_id, user["id"], pv_name, pv_x, pv_y, user["display_name"], pv_pts, pv_blds, pv_res, pv_units, now, pv_prot, pv_cprot, pv_id))
            elif not v_exist:
                cursor.execute("""
                    INSERT INTO villages (
                        id, world_id, user_id, name, x, y, owner, points, is_bot, is_barbarian,
                        buildings_json, resources_json, units_json, last_calc_unix,
                        protection_until_unix, conquest_protection_until_unix
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?)
                """, (pv_id, w_id, user["id"], pv_name, pv_x, pv_y, user["display_name"], pv_pts, pv_blds, pv_res, pv_units, now, pv_prot, pv_cprot))

        needs_worlds_write = (
            ws_row is None
            or len(merged_w.get("registered_real_players", [])) != len((server_w or {}).get("registered_real_players", []))
        )
        worlds_meta = _sync_worlds_table_from_states(cursor, now, write_updates=needs_worlds_write)

    return {
        "ok": True,
        "updated_unix": now,
        "world_id": w_id,
        "display_name": user["display_name"],
        "cloud_state": merged_for_player,
        "worlds_meta": worlds_meta,
    }


@app.get("/api/reports")
def get_reports(user: Dict[str, Any] = Depends(get_current_user)):
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM reports WHERE user_name = ? ORDER BY created_unix DESC LIMIT 50
        """, (user["display_name"],))
        rows = cursor.fetchall()
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


# -----------------------------------------------------------------------------
# Kraliyet Pazarı: Elmas Paketleri, Hızlandırma Parşömenleri ve StoreKit IAP
# -----------------------------------------------------------------------------
def _find_scroll_def(scroll_id: str) -> Optional[Dict[str, Any]]:
    for s in SPEEDUP_SCROLLS:
        if s["id"] == scroll_id:
            return s
    return None


def _find_pack_def(product_id: str, pack_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
    for p in DIAMOND_PACKS:
        if p["product_id"] == product_id or p["id"] == product_id or (pack_id and p["id"] == pack_id):
            return p
    return None


def _find_resource_pack_def(pack_id: str) -> Optional[Dict[str, Any]]:
    for rp in RESOURCE_PACKS:
        if rp["id"] == pack_id:
            return rp
    return None


@app.get("/api/store/catalog")
def store_catalog(authorization: Optional[str] = Header(None)):
    res: Dict[str, Any] = {
        "ok": True,
        "starter_diamonds": STARTER_DIAMONDS,
        "diamond_packs": DIAMOND_PACKS,
        "speedup_scrolls": SPEEDUP_SCROLLS,
        "resource_packs": RESOURCE_PACKS,
    }
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "").strip()
        if token:
            conn = get_db()
            with conn:
                cursor = conn.cursor()
                ensure_cloud_saves_table(cursor, conn.is_pg)
                cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE token = ?", (token,))
                u_row = cursor.fetchone()
            if u_row:
                d, s = _parse_user_wallet(dict(u_row))
                res["diamonds"] = d
                res["scrolls"] = s
    return res


@app.post("/api/store/buy_scroll")
def store_buy_scroll(req: BuyScrollRequest, user: Dict[str, Any] = Depends(get_current_user)):
    scroll_def = _find_scroll_def(req.scroll_id)
    if not scroll_def:
        raise HTTPException(status_code=400, detail="Geçersiz parşömen kimliği.")

    now = int(time.time())
    cost = int(scroll_def["cost_diamonds"]) * int(req.qty)
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user["id"],))
        u_row = cursor.fetchone()
        cur_diamonds, scrolls = _parse_user_wallet(dict(u_row) if u_row else user)
        if cur_diamonds < cost:
            raise HTTPException(status_code=400, detail=f"Yetersiz elmas (Gereken: {cost}, Mevcut: {cur_diamonds}).")

        new_diamonds = cur_diamonds - cost
        new_count = int(scrolls.get(req.scroll_id, 0)) + int(req.qty)
        scrolls[req.scroll_id] = new_count
        cursor.execute(
            "UPDATE users SET diamonds = ?, scrolls_json = ? WHERE id = ?",
            (new_diamonds, json.dumps(scrolls, ensure_ascii=False), user["id"]),
        )
        _sync_wallet_to_world_profiles(cursor, user["display_name"], new_diamonds, scrolls, now)

    return {
        "ok": True,
        "diamonds": new_diamonds,
        "scrolls": scrolls,
        "scroll_id": req.scroll_id,
        "qty": req.qty,
        "count": new_count,
        "added": 0,
    }


@app.post("/api/store/use_scroll")
def store_use_scroll(req: UseScrollRequest, user: Dict[str, Any] = Depends(get_current_user)):
    scroll_def = _find_scroll_def(req.scroll_id)
    if not scroll_def:
        raise HTTPException(status_code=400, detail="Geçersiz parşömen kimliği.")

    now = int(time.time())
    scroll_secs = max(1, int(scroll_def["seconds"]))
    cat = str(req.category or scroll_def["category"]).strip()

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user["id"],))
        u_row = cursor.fetchone()
        cur_diamonds, scrolls = _parse_user_wallet(dict(u_row) if u_row else user)
        have_cnt = int(scrolls.get(req.scroll_id, 0) or 0)
        if have_cnt < 1:
            raise HTTPException(status_code=400, detail="Bu parşömenden envanterinizde yok.")

        next_cnt = have_cnt - 1
        if next_cnt > 0:
            scrolls[req.scroll_id] = next_cnt
        else:
            scrolls.pop(req.scroll_id, None)

        cursor.execute(
            "UPDATE users SET scrolls_json = ? WHERE id = ?",
            (json.dumps(scrolls, ensure_ascii=False), user["id"]),
        )
        _sync_wallet_to_world_profiles(cursor, user["display_name"], cur_diamonds, scrolls, now)

        # Ayrıca world_states içindeki eşleşen aktif sefer veya kuyruk süresini de sunucuda kısalt
        norm_p = _norm_p_name(user["display_name"])
        cursor.execute("SELECT world_id, state_json FROM world_states ORDER BY world_id ASC")
        for ws in cursor.fetchall():
            wid = int(ws["world_id"])
            try:
                w_data = json.loads(ws["state_json"])
            except Exception:
                continue
            state = w_data.get("state")
            if not isinstance(state, dict):
                continue
            owned_vids = {
                int(v.get("id", 0) or 0)
                for v in (state.get("villages") or [])
                if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), norm_p)
            }
            if not owned_vids:
                continue
            changed_ws = False
            if cat == "march":
                for m in (state.get("movements") or []):
                    if not isinstance(m, dict):
                        continue
                    is_ret = (str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return")
                    m_owner = str(m.get("owner", "")).strip()
                    belongs = (
                        (m_owner and _matches_player(m_owner, norm_p))
                        or int(m.get("village_id", 0) or 0) in owned_vids
                        or (not is_ret and int(m.get("from_village_id", 0) or 0) in owned_vids)
                        or (is_ret and int(m.get("to_village_id", 0) or 0) in owned_vids)
                    )
                    if not belongs:
                        continue
                    if req.target_id is not None and str(req.target_id) != "" and str(m.get("id", "")) != str(req.target_id):
                        continue
                    old_arr = int(m.get("arrive_unix", now) or now)
                    dep_u = int(m.get("depart_unix", now) or now)
                    if "base_travel_seconds" not in m:
                        m["base_travel_seconds"] = max(1, old_arr - dep_u)
                    applied = min(max(0, old_arr - now), scroll_secs)
                    if applied <= 0 and old_arr > now:
                        applied = min(old_arr - now, scroll_secs)
                    new_arr = max(1, old_arr - applied)
                    m["arrive_unix"] = new_arr
                    m["depart_unix"] = dep_u - applied
                    m["return_unix"] = new_arr if is_ret else (new_arr + int(m["base_travel_seconds"]))
                    changed_ws = True
                    break
            elif cat in ("build", "train", "research"):
                target_vid = int(req.village_id or state.get("active_village_id", -1) or -1)
                if target_vid not in owned_vids and owned_vids:
                    target_vid = sorted(owned_vids)[0]
                matching_q = [
                    q for q in (state.get("queues") or [])
                    if isinstance(q, dict) and int(q.get("village_id", -1) or -1) == target_vid and str(q.get("type", "")) == cat
                ]
                matching_q.sort(key=lambda q: (int(q.get("start_unix", 0) or 0), int(q.get("finish_unix", 0) or 0), int(q.get("id", 0) or 0)))
                if matching_q:
                    pool = scroll_secs
                    saved = 0
                    for idx_q, q in enumerate(matching_q):
                        old_s = int(q.get("start_unix", now) or now)
                        old_f = int(q.get("finish_unix", now) or now)
                        if idx_q > 0 and saved > 0 and old_s > now:
                            sh = min(saved, old_s - now)
                            old_s -= sh
                            old_f = max(old_s, old_f - sh)
                            q["start_unix"] = old_s
                            q["finish_unix"] = old_f
                        if pool > 0:
                            eff_s = max(now, old_s)
                            cur_rem = max(0, old_f - eff_s)
                            rem_s = min(cur_rem, pool)
                            new_f = max(1, old_f - rem_s)
                            q["finish_unix"] = new_f
                            pool -= rem_s
                            saved += rem_s
                            changed_ws = True
                    # Tamamlanan inşaat kuyruğu öğelerini sunucu köy binalarına da yansıt ki yarışta seviye düşmesin
                    if cat == "build":
                        completed_qs = [q for q in matching_q if int(q.get("finish_unix", now + 1) or (now + 1)) <= now]
                        if completed_qs:
                            completed_ids = {id(q) for q in completed_qs}
                            for cq in completed_qs:
                                q_key = str(cq.get("key", "") or "")
                                tgt_lvl = int(cq.get("target_level", 0) or 0)
                                for sv in (state.get("villages") or []):
                                    if isinstance(sv, dict) and int(sv.get("id", -1) or -1) == target_vid:
                                        sblds = sv.setdefault("buildings", {})
                                        if q_key and isinstance(sblds, dict):
                                            cur_l = int(sblds.get(q_key, 0) or 0)
                                            next_l = tgt_lvl if tgt_lvl > cur_l else (cur_l + 1)
                                            sblds[q_key] = max(cur_l, next_l)
                                        break
                            state["queues"] = [q for q in (state.get("queues") or []) if id(q) not in completed_ids]
            if changed_ws:
                w_data["last_saved_unix"] = now
                cursor.execute(
                    "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                    (json.dumps(w_data, ensure_ascii=False), now, wid),
                )

    return {
        "ok": True,
        "diamonds": cur_diamonds,
        "scrolls": scrolls,
        "scroll_id": req.scroll_id,
        "count": next_cnt,
    }


@app.post("/api/store/buy_resources")
def store_buy_resources(req: BuyResourcesRequest, user: Dict[str, Any] = Depends(get_current_user)):
    rpack = _find_resource_pack_def(req.pack_id)
    if not rpack:
        raise HTTPException(status_code=400, detail="Geçersiz kaynak paketi kimliği.")

    now = int(time.time())
    cost = int(rpack["cost_diamonds"])
    conn = get_db()
    added_resources = {"wood": 0, "stone": 0, "iron": 0}
    new_resources = {"wood": 0, "stone": 0, "iron": 0}

    with conn:
        cursor = conn.cursor()
        ensure_cloud_saves_table(cursor, conn.is_pg)
        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user["id"],))
        u_row = cursor.fetchone()
        cur_diamonds, scrolls = _parse_user_wallet(dict(u_row) if u_row else user)
        if cur_diamonds < cost:
            raise HTTPException(status_code=400, detail=f"Yetersiz elmas (Gereken: {cost}, Mevcut: {cur_diamonds}).")

        new_diamonds = cur_diamonds - cost
        cursor.execute("UPDATE users SET diamonds = ? WHERE id = ?", (new_diamonds, user["id"]))
        _sync_wallet_to_world_profiles(cursor, user["display_name"], new_diamonds, scrolls, now)

        norm_p = _norm_p_name(user["display_name"])
        cursor.execute("SELECT world_id, state_json FROM world_states ORDER BY world_id ASC")
        for ws in cursor.fetchall():
            wid = int(ws["world_id"])
            try:
                w_data = json.loads(ws["state_json"])
            except Exception:
                continue
            state = w_data.get("state")
            if not isinstance(state, dict):
                continue
            target_v = None
            for v in (state.get("villages") or []):
                if _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), norm_p):
                    if req.village_id is None or int(v.get("id", -1) or -1) == int(req.village_id):
                        target_v = v
                        break
                    if target_v is None:
                        target_v = v
            if target_v is not None:
                blds = target_v.get("buildings") if isinstance(target_v.get("buildings"), dict) else {}
                st_lvl = max(1, int(blds.get("storage", blds.get("warehouse", 1)) or 1))
                cap = int(round(1000.0 * (1.2335 ** max(0, st_lvl - 1))))
                cap = max(1000, cap)
                res = target_v.setdefault("resources", {"wood": 500, "stone": 500, "iron": 500})
                for rk in ("wood", "stone", "iron"):
                    cur_val = max(0, int(res.get(rk, 0) or 0))
                    if bool(rpack.get("fill_storage", False)):
                        next_val = max(cur_val, cap)
                    else:
                        add_v = int(rpack.get(rk, 0) or 0)
                        next_val = min(cap, cur_val + add_v) if add_v > 0 else cur_val
                    added_resources[rk] = max(0, next_val - cur_val)
                    res[rk] = next_val
                    new_resources[rk] = next_val
                w_data["last_saved_unix"] = now
                cursor.execute(
                    "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                    (json.dumps(w_data, ensure_ascii=False), now, wid),
                )
                break

    return {
        "ok": True,
        "pack_id": req.pack_id,
        "diamonds": new_diamonds,
        "scrolls": scrolls,
        "added_resources": added_resources,
        "resources": new_resources,
    }


@app.post("/api/store/verify_iap")
def store_verify_iap(req: VerifyIapRequest, user: Dict[str, Any] = Depends(get_current_user)):
    pack = _find_pack_def(req.product_id, req.pack_id)
    if not pack:
        raise HTTPException(status_code=400, detail="Bilinmeyen elmas paketi.")

    tx_id = req.transaction_id.strip()
    if not tx_id:
        raise HTTPException(status_code=400, detail="Geçersiz işlem kimliği.")

    now = int(time.time())
    add_amt = int(pack["diamonds"])
    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)
        cursor.execute("SELECT transaction_id FROM iap_transactions WHERE transaction_id = ?", (tx_id,))
        existing_tx = cursor.fetchone()
        cursor.execute("SELECT diamonds, scrolls_json FROM users WHERE id = ?", (user["id"],))
        u_row = cursor.fetchone()
        cur_diamonds, scrolls = _parse_user_wallet(dict(u_row) if u_row else user)

        if existing_tx:
            return {
                "ok": True,
                "diamonds": cur_diamonds,
                "scrolls": scrolls,
                "added": 0,
                "duplicate": True,
                "transaction_id": tx_id,
            }

        cursor.execute(
            """INSERT INTO iap_transactions
               (transaction_id, user_id, product_id, pack_id, diamonds_added, platform, receipt_data, created_unix)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (tx_id, user["id"], pack["product_id"], pack["id"], add_amt, req.platform[:40], (req.receipt_data or "")[:32768], now),
        )
        new_diamonds = cur_diamonds + add_amt
        cursor.execute("UPDATE users SET diamonds = ? WHERE id = ?", (new_diamonds, user["id"]))
        _sync_wallet_to_world_profiles(cursor, user["display_name"], new_diamonds, scrolls, now)

    return {
        "ok": True,
        "diamonds": new_diamonds,
        "scrolls": scrolls,
        "added": add_amt,
        "duplicate": False,
        "transaction_id": tx_id,
    }


# -----------------------------------------------------------------------------
# Google / Apple OAuth Akış Sayfaları (iOS ASWebAuthenticationSession & Web)
# -----------------------------------------------------------------------------
class OAuthSubmitRequest(BaseModel):
    session: str = Field(..., min_length=4, max_length=120)
    provider: str = Field("google", max_length=20)
    email: Optional[str] = Field("", max_length=120)
    name: Optional[str] = Field("", max_length=80)
    cancelled: bool = False


def _derive_name_from_email(raw_email: str, fallback: str) -> str:
    clean = str(raw_email or "").strip()
    if "@" in clean:
        local = clean.split("@", 1)[0].strip()
        parts = [p for p in re.split(r"[._\-]+", local) if p]
        if parts:
            return " ".join(p.capitalize() for p in parts[:3])
    return fallback


@app.get("/api/auth/oauth_page", response_class=HTMLResponse)
def oauth_page(
    provider: str = Query("google"),
    session: str = Query(""),
    platform: str = Query("web"),
):
    prov = "apple" if str(provider).strip().lower() == "apple" else "google"
    plat = "ios" if str(platform).strip().lower() == "ios" else "web"
    sess = re.sub(r"[^a-zA-Z0-9_\-]", "", str(session or "")) or secrets.token_hex(12)
    now = int(time.time())

    try:
        conn = get_db()
        with conn:
            cur = conn.cursor()
            ensure_cloud_saves_table(cur, conn.is_pg)
            cur.execute("SELECT session_id FROM oauth_sessions WHERE session_id = ?", (sess,))
            if cur.fetchone():
                cur.execute(
                    "UPDATE oauth_sessions SET status = 'pending', provider = ?, payload_json = '{}', updated_unix = ? WHERE session_id = ?",
                    (prov, now, sess)
                )
            else:
                cur.execute(
                    "INSERT INTO oauth_sessions (session_id, status, provider, payload_json, updated_unix) VALUES (?, 'pending', ?, '{}', ?)",
                    (sess, prov, now)
                )
    except Exception:
        pass

    is_apple = (prov == "apple")
    title = "Apple ID ile Giriş Yap" if is_apple else "Google Hesabı ile Oturum Aç"
    subtitle = (
        "iCloud / Apple e-posta adresinizi seçin veya Face ID / Passkey ile doğrulayın."
        if is_apple
        else "Devam etmek için Google (@gmail.com) hesabınızı seçin veya e-postanızı girin."
    )
    email_ph = "ornek@icloud.com" if is_apple else "ornek@gmail.com"
    accent = "#ffffff" if is_apple else "#1a73e8"
    bg_grad = "linear-gradient(160deg,#0f1118,#191d28)" if is_apple else "linear-gradient(160deg,#f5f7fb,#e9eef6)"
    card_bg = "#171a24" if is_apple else "#ffffff"
    fg = "#f4f6fb" if is_apple else "#1f2430"
    muted = "#9ba3b4" if is_apple else "#5f6368"
    inp_bg = "#0d1017" if is_apple else "#f8f9fc"
    inp_border = "#353c4d" if is_apple else "#dadce0"
    btn_bg = "#f5f6fa" if is_apple else "#1a73e8"
    btn_fg = "#101218" if is_apple else "#ffffff"
    badge = " Apple" if is_apple else "G Google"

    html_doc = f"""<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no" />
  <title>{html.escape(title)} — Taht ve Kılıç</title>
  <style>
    * {{ box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }}
    body {{ margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: {bg_grad}; color: {fg}; padding: 18px; }}
    .card {{ width: 100%; max-width: 420px; background: {card_bg}; border-radius: 18px; padding: 26px 22px; box-shadow: 0 18px 48px rgba(0,0,0,0.22); border: 1px solid {inp_border}; }}
    .brand {{ font-size: 15px; font-weight: 700; letter-spacing: 0.4px; color: {accent}; margin-bottom: 10px; }}
    h1 {{ font-size: 22px; margin: 0 0 8px 0; }}
    .sub {{ font-size: 14px; color: {muted}; margin: 0 0 18px 0; line-height: 1.45; }}
    .saved-list {{ display: flex; flex-direction: column; gap: 8px; margin-bottom: 16px; }}
    .acct-btn {{ display: flex; align-items: center; gap: 12px; width: 100%; text-align: left; background: {inp_bg}; color: {fg}; border: 1px solid {inp_border}; border-radius: 12px; padding: 11px 14px; cursor: pointer; font-size: 14px; }}
    .acct-avatar {{ width: 34px; height: 34px; border-radius: 50%; background: {btn_bg}; color: {btn_fg}; display: flex; align-items: center; justify-content: center; font-weight: 700; flex-shrink: 0; }}
    label {{ display: block; font-size: 13px; font-weight: 600; margin: 10px 0 6px 0; color: {muted}; }}
    input {{ width: 100%; padding: 13px 14px; border-radius: 11px; border: 1.5px solid {inp_border}; background: {inp_bg}; color: {fg}; font-size: 16px; outline: none; }}
    input:focus {{ border-color: #1a73e8; }}
    .actions {{ display: flex; flex-direction: column; gap: 10px; margin-top: 18px; }}
    .primary {{ width: 100%; padding: 14px; border: none; border-radius: 12px; background: {btn_bg}; color: {btn_fg}; font-size: 16px; font-weight: 700; cursor: pointer; }}
    .secondary {{ width: 100%; padding: 12px; border: 1px solid {inp_border}; border-radius: 12px; background: transparent; color: {muted}; font-size: 15px; font-weight: 600; cursor: pointer; }}
    .err {{ color: #e5484d; font-size: 13px; margin-top: 10px; min-height: 18px; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">{html.escape(badge)} &bull; Taht ve Kılıç</div>
    <h1>{html.escape(title)}</h1>
    <p class="sub">{html.escape(subtitle)}</p>
    <div id="savedList" class="saved-list"></div>
    <form id="authForm" autocomplete="on">
      <label for="email">{"Apple ID E-posta" if is_apple else "Google E-posta (@gmail.com)"}</label>
      <input id="email" name="email" type="email" inputmode="email" autocomplete="email" placeholder="{html.escape(email_ph)}" required />
      <div id="errBox" class="err"></div>
      <div class="actions">
        <button class="primary" type="submit" id="submitBtn">{"Apple ile Devam Et" if is_apple else "Google ile Devam Et"}</button>
        <button class="secondary" type="button" id="cancelBtn">İptal</button>
      </div>
    </form>
  </div>
  <script>
    (function() {{
      const PROV = {json.dumps(prov)};
      const SESS = {json.dumps(sess)};
      const PLAT = {json.dumps(plat)};
      const STORE_KEY = "tvk_oauth_accounts_" + PROV;
      const savedDiv = document.getElementById("savedList");
      const emailInp = document.getElementById("email");
      const errBox = document.getElementById("errBox");
      const submitBtn = document.getElementById("submitBtn");

      function loadSaved() {{
        try {{
          const list = JSON.parse(localStorage.getItem(STORE_KEY) || "[]");
          return Array.isArray(list) ? list : [];
        }} catch(e) {{ return []; }}
      }}
      function saveAccount(email) {{
        try {{
          let list = loadSaved().filter(a => a && a.email && a.email.toLowerCase() !== email.toLowerCase());
          list.unshift({{ email }});
          localStorage.setItem(STORE_KEY, JSON.stringify(list.slice(0, 5)));
        }} catch(e) {{}}
      }}
      function renderSaved() {{
        const list = loadSaved();
        savedDiv.innerHTML = "";
        list.forEach(acc => {{
          const btn = document.createElement("button");
          btn.type = "button";
          btn.className = "acct-btn";
          const ch = (acc.email || "?").charAt(0).toUpperCase();
          const av = document.createElement("div");
          av.className = "acct-avatar";
          av.textContent = ch;
          const info = document.createElement("div");
          const b = document.createElement("div");
          b.style.fontWeight = "700";
          b.textContent = acc.email;
          info.appendChild(b);
          btn.appendChild(av);
          btn.appendChild(info);
          btn.onclick = () => completeLogin(acc.email);
          savedDiv.appendChild(btn);
        }});
      }}
      async function maybePasskey(email) {{
        if (PROV === "apple" && window.PublicKeyCredential && PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {{
          try {{
            const ok = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
            if (ok && navigator.credentials && navigator.credentials.create) {{
              const ch = new Uint8Array(16);
              crypto.getRandomValues(ch);
              await navigator.credentials.create({{
                publicKey: {{
                  challenge: ch,
                  rp: {{ name: "Taht ve Kilic" }},
                  user: {{ id: new TextEncoder().encode(email), name: email, displayName: email }},
                  pubKeyCredParams: [{{ type: "public-key", alg: -7 }}, {{ type: "public-key", alg: -257 }}],
                  authenticatorSelection: {{ authenticatorAttachment: "platform", userVerification: "required" }},
                  timeout: 15000
                }}
              }}).catch(e => {{
                if (e && e.name === "NotAllowedError") throw e;
              }});
            }}
          }} catch(e) {{
            if (e && e.name === "NotAllowedError") return false;
          }}
        }}
        return true;
      }}
      async function completeLogin(emailVal) {{
        const cleanEmail = (emailVal || "").trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes("@")) {{
          errBox.textContent = "Lütfen geçerli bir e-posta adresi girin.";
          return;
        }}
        submitBtn.disabled = true;
        errBox.textContent = "";
        if (PLAT === "web") {{
          const passOk = await maybePasskey(cleanEmail);
          if (!passOk) {{
            submitBtn.disabled = false;
            errBox.textContent = "Face ID / Passkey doğrulaması iptal edildi.";
            return;
          }}
        }}
        const res = await fetch("/api/auth/oauth_submit", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{ session: SESS, provider: PROV, email: cleanEmail, name: "", cancelled: false }})
        }});
        const data = await res.json();
        saveAccount(data.email || cleanEmail);
        if (PLAT === "ios") {{
          const qs = new URLSearchParams({{
            ok: "1",
            provider: PROV,
            email: data.email || cleanEmail,
            name: "",
            provider_uid: data.provider_uid || ""
          }});
          window.location.href = "tahtkilic://auth?" + qs.toString();
        }} else {{
          const msg = {{ type: "tvk_oauth", ok: true, session: SESS, provider: PROV, email: data.email, name: "", provider_uid: data.provider_uid }};
          try {{ if (window.parent && window.parent !== window) window.parent.postMessage(msg, "*"); }} catch(e) {{}}
          try {{ if (window.opener) window.opener.postMessage(msg, "*"); }} catch(e) {{}}
          setTimeout(() => {{ try {{ window.close(); }} catch(e) {{}} }}, 150);
        }}
      }}
      document.getElementById("authForm").onsubmit = (ev) => {{
        ev.preventDefault();
        completeLogin(emailInp.value);
      }};
      document.getElementById("cancelBtn").onclick = async () => {{
        try {{
          await fetch("/api/auth/oauth_submit", {{
            method: "POST",
            headers: {{ "Content-Type": "application/json" }},
            body: JSON.stringify({{ session: SESS, provider: PROV, cancelled: true }})
          }});
        }} catch(e) {{}}
        if (PLAT === "ios") {{
          window.location.href = "tahtkilic://auth?ok=0&cancelled=1";
        }} else {{
          const msg = {{ type: "tvk_oauth", ok: false, cancelled: true, session: SESS }};
          try {{ if (window.parent && window.parent !== window) window.parent.postMessage(msg, "*"); }} catch(e) {{}}
          try {{ if (window.opener) window.opener.postMessage(msg, "*"); }} catch(e) {{}}
          try {{ window.close(); }} catch(e) {{}}
        }}
      }};
      renderSaved();
    }})();
  </script>
</body>
</html>"""
    return HTMLResponse(content=html_doc)


@app.post("/api/auth/oauth_submit")
def oauth_submit(req: OAuthSubmitRequest):
    now = int(time.time())
    prov = "apple" if (req.provider or "").strip().lower() == "apple" else "google"
    sess = re.sub(r"[^a-zA-Z0-9_\-]", "", str(req.session or ""))
    if req.cancelled:
        payload = {"ok": False, "cancelled": True, "provider": prov}
        status = "cancelled"
    else:
        clean_email = (req.email or "").strip().lower()
        raw_name = (req.name or "").strip()
        norm_name = normalize_display_name(raw_name) if raw_name else ""
        uid_key = clean_email or norm_name.lower() or sess
        uid = f"{prov}_{hashlib.sha256((prov + ':' + uid_key).encode('utf-8')).hexdigest()[:14]}"
        payload = {
            "ok": True,
            "cancelled": False,
            "provider": prov,
            "email": clean_email,
            "name": norm_name,
            "provider_uid": uid,
        }
        status = "done"

    payload_str = json.dumps(payload, ensure_ascii=False)
    conn = get_db()
    with conn:
        cur = conn.cursor()
        ensure_cloud_saves_table(cur, conn.is_pg)
        cur.execute("SELECT session_id FROM oauth_sessions WHERE session_id = ?", (sess,))
        if cur.fetchone():
            cur.execute(
                "UPDATE oauth_sessions SET status = ?, provider = ?, payload_json = ?, updated_unix = ? WHERE session_id = ?",
                (status, prov, payload_str, now, sess)
            )
        else:
            cur.execute(
                "INSERT INTO oauth_sessions (session_id, status, provider, payload_json, updated_unix) VALUES (?, ?, ?, ?, ?)",
                (sess, status, prov, payload_str, now)
            )
    return payload


@app.get("/api/auth/oauth_poll")
def oauth_poll(session: str = Query(...)):
    sess = re.sub(r"[^a-zA-Z0-9_\-]", "", str(session or ""))
    conn = get_db()
    with conn:
        cur = conn.cursor()
        ensure_cloud_saves_table(cur, conn.is_pg)
        cur.execute("SELECT status, provider, payload_json FROM oauth_sessions WHERE session_id = ?", (sess,))
        row = cur.fetchone()
    if not row:
        return {"ok": True, "status": "pending", "data": {}}
    try:
        data = json.loads(row["payload_json"])
    except Exception:
        data = {}
    return {"ok": True, "status": row["status"], "provider": row["provider"], "data": data}


def _wipe_player_from_world_state(w_data: Dict[str, Any], norm_p: str) -> Dict[str, Any]:
    if not isinstance(w_data, dict):
        return w_data
    state = w_data.get("state")
    if not isinstance(state, dict):
        return w_data

    owned_vids = set()
    kept_villages = []
    for v in (state.get("villages") or []):
        if isinstance(v, dict) and _is_real_player_village(v) and _matches_player(str(v.get("owner", "")), norm_p):
            try:
                owned_vids.add(int(v.get("id", 0) or 0))
            except Exception:
                pass
            continue
        kept_villages.append(v)
    state["villages"] = kept_villages
    _rebuild_tiles(state)

    if isinstance(state.get("queues"), list):
        state["queues"] = [
            q for q in state["queues"]
            if not (isinstance(q, dict) and int(q.get("village_id", 0) or 0) in owned_vids)
        ]

    if isinstance(state.get("movements"), list):
        kept_movs = []
        for m in state["movements"]:
            if not isinstance(m, dict):
                continue
            m_owner = str(m.get("owner", "") or "").strip()
            m_vid = int(m.get("village_id", 0) or 0)
            fv = int(m.get("from_village_id", 0) or 0)
            tv = int(m.get("to_village_id", 0) or 0)
            is_ret = (str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return")
            belongs = (
                (m_owner and _matches_player(m_owner, norm_p))
                or m_vid in owned_vids
                or (not is_ret and fv in owned_vids)
                or (is_ret and tv in owned_vids)
            )
            if not belongs:
                kept_movs.append(m)
        state["movements"] = kept_movs

    if isinstance(state.get("reports"), list):
        kept_reps = []
        for rep in state["reports"]:
            if not isinstance(rep, dict):
                continue
            r_vid = int(rep.get("village_id", 0) or 0)
            if r_vid in owned_vids:
                continue
            kept_reps.append(rep)
        state["reports"] = kept_reps

    if isinstance(state.get("messages"), list):
        kept_msgs = []
        for msg in state["messages"]:
            if not isinstance(msg, dict):
                continue
            fn = str(msg.get("from", msg.get("from_name", "")) or "")
            tn = str(msg.get("to", msg.get("to_name", "")) or "")
            if _matches_player(fn, norm_p) or _matches_player(tn, norm_p):
                continue
            kept_msgs.append(msg)
        state["messages"] = kept_msgs

    if isinstance(state.get("alliances"), list):
        kept_alliances = []
        for a in state["alliances"]:
            if not isinstance(a, dict):
                continue
            mems = [
                m for m in (a.get("members") or [])
                if not (isinstance(m, dict) and _matches_player(str(m.get("name", "")), norm_p))
            ]
            if not mems:
                continue
            a["members"] = mems
            if _matches_player(str(a.get("leader", "")), norm_p):
                a["leader"] = str(mems[0].get("name", ""))
                mems[0]["rank"] = "leader"
            if isinstance(a.get("invitations"), list):
                a["invitations"] = [
                    inv for inv in a["invitations"]
                    if not (isinstance(inv, dict) and _matches_player(str(inv.get("player_name", "")), norm_p))
                ]
            kept_alliances.append(a)
        state["alliances"] = kept_alliances

    w_dict = state.get("world")
    if isinstance(w_dict, dict):
        profs = w_dict.get("player_profiles")
        if isinstance(profs, dict):
            for pk in [k for k in profs.keys() if _matches_player(str(k), norm_p)]:
                profs.pop(pk, None)
        psb = w_dict.get("player_starter_boost")
        if isinstance(psb, dict):
            for bk in [k for k in psb.keys() if _matches_player(str(k), norm_p)]:
                psb.pop(bk, None)

    reg_players = w_data.get("registered_real_players")
    if isinstance(reg_players, list):
        w_data["registered_real_players"] = [
            rp for rp in reg_players if not _matches_player(str(rp), norm_p)
        ]
    return w_data


@app.post("/api/account/delete")
def delete_account(user: Dict[str, Any] = Depends(get_current_user)):
    now = int(time.time())
    uid = str(user["id"])
    dname = str(user.get("display_name") or "").strip()
    norm_p = _norm_p_name(dname)
    name_variants = list(_name_variants(dname)) or ([norm_p] if norm_p else [])

    conn = get_db()
    with conn:
        cursor = conn.cursor()
        if conn.is_pg:
            cursor.execute("SET LOCAL statement_timeout = '8000'; SET LOCAL lock_timeout = '3000'")
        ensure_cloud_saves_table(cursor, conn.is_pg)

        cursor.execute("DELETE FROM cloud_saves WHERE user_id = ?", (uid,))
        cursor.execute("DELETE FROM queues WHERE user_id = ?", (uid,))
        cursor.execute("DELETE FROM movements WHERE user_id = ?", (uid,))
        cursor.execute("DELETE FROM villages WHERE user_id = ?", (uid,))
        cursor.execute("DELETE FROM iap_transactions WHERE user_id = ?", (uid,))

        for nm in name_variants:
            cursor.execute("DELETE FROM villages WHERE LOWER(owner) = LOWER(?) AND is_bot = 0", (nm,))
            cursor.execute("DELETE FROM reports WHERE LOWER(user_name) = LOWER(?)", (nm,))
            cursor.execute("DELETE FROM messages WHERE LOWER(from_name) = LOWER(?) OR LOWER(to_name) = LOWER(?)", (nm, nm))
            cursor.execute("DELETE FROM alliance_invitations WHERE LOWER(user_name) = LOWER(?) OR LOWER(invited_by) = LOWER(?)", (nm, nm))
            cursor.execute("DELETE FROM alliance_members WHERE LOWER(user_name) = LOWER(?)", (nm,))

        if name_variants:
            cursor.execute("SELECT id, leader_name, founder_name FROM alliances")
            for ar in cursor.fetchall():
                ar_d = dict(ar)
                if _matches_player(str(ar_d.get("leader_name") or ""), norm_p) or _matches_player(str(ar_d.get("founder_name") or ""), norm_p):
                    aid = ar_d["id"]
                    cursor.execute("SELECT user_name FROM alliance_members WHERE alliance_id = ? ORDER BY joined_unix ASC LIMIT 1", (aid,))
                    next_m = cursor.fetchone()
                    if next_m:
                        next_leader = str(next_m["user_name"])
                        cursor.execute("UPDATE alliances SET leader_name = ? WHERE id = ?", (next_leader, aid))
                        cursor.execute("UPDATE alliance_members SET rank = 'leader' WHERE alliance_id = ? AND user_name = ?", (aid, next_leader))
                    else:
                        cursor.execute("DELETE FROM alliance_invitations WHERE alliance_id = ?", (aid,))
                        cursor.execute("DELETE FROM alliances WHERE id = ?", (aid,))

        cursor.execute("SELECT world_id, state_json FROM world_states ORDER BY world_id ASC")
        for ws in cursor.fetchall():
            wid = int(ws["world_id"])
            try:
                w_data = json.loads(ws["state_json"])
            except Exception:
                continue
            cleaned_w = _wipe_player_from_world_state(w_data, norm_p)
            cleaned_w["last_saved_unix"] = now
            cursor.execute(
                "UPDATE world_states SET state_json = ?, updated_unix = ? WHERE world_id = ?",
                (json.dumps(cleaned_w, ensure_ascii=False), now, wid),
            )

        cursor.execute("DELETE FROM users WHERE id = ?", (uid,))
        _sync_worlds_table_from_states(cursor, now)

    return {"ok": True, "deleted": True}
