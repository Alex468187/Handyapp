"""Claude-Werkzeug: liest und schreibt Summer-Daten direkt in Supabase.

Passwort kommt aus der Umgebungsvariable SUMMER_DB_PASSWORD (steht in
Obsidian unter Zugänge/Supabase). Braucht das Paket psycopg (v3).

  python tool/summer_db.py schema                    # Tabelle anlegen/aktualisieren
  python tool/summer_db.py users                     # angemeldete Nutzer
  python tool/summer_db.py list [task|chore|note]    # Einträge anzeigen
  python tool/summer_db.py note "Titel" "Text"       # Notiz anlegen
  python tool/summer_db.py chore "Titel" [perDay]    # Aufgabe ohne Termin
  python tool/summer_db.py task "Titel" 2026-11-20 [HH:MM]   # einmaliger Termin
  python tool/summer_db.py put task|chore|note '<json>'      # beliebiger Eintrag
  python tool/summer_db.py delete <id>               # Eintrag löschen
"""
import datetime as dt
import json
import os
import pathlib
import random
import sys

import psycopg

REF = "fhilcpvkwppttywkjgep"
CONN = dict(
    host="aws-0-eu-west-1.pooler.supabase.com",
    port=5432,
    user=f"postgres.{REF}",
    dbname="postgres",
    sslmode="require",
    connect_timeout=10,
)


def connect():
    pw = os.environ.get("SUMMER_DB_PASSWORD")
    if not pw:
        sys.exit("SUMMER_DB_PASSWORD fehlt")
    return psycopg.connect(password=pw, autocommit=True, **CONN)


def new_id():
    now = dt.datetime.now()
    return f"{int(now.timestamp() * 1_000_000)}-{random.randrange(1 << 32)}"


def the_user(c):
    rows = c.execute("select id, email from auth.users order by created_at").fetchall()
    if not rows:
        sys.exit("Noch niemand in der App angemeldet.")
    if len(rows) > 1:
        print("Hinweis: mehrere Nutzer, nehme den ersten:", rows[0][1], file=sys.stderr)
    return rows[0][0]


def put(c, kind, data):
    uid = the_user(c)
    data.setdefault("id", new_id())
    c.execute(
        """insert into public.items (user_id, id, kind, data, deleted)
           values (%s, %s, %s, %s, false)
           on conflict (user_id, id) do update
             set kind = excluded.kind, data = excluded.data, deleted = false""",
        (uid, data["id"], kind, json.dumps(data, ensure_ascii=False)),
    )
    print("gespeichert:", kind, data["id"], data.get("title", ""))


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    with connect() as c:
        if cmd == "schema":
            sql = (pathlib.Path(__file__).parent.parent / "supabase" / "schema.sql").read_text(encoding="utf-8")
            c.execute(sql)
            print("Schema OK")
        elif cmd == "users":
            for r in c.execute("select id, email, email_confirmed_at, created_at from auth.users"):
                print(*r)
        elif cmd == "list":
            q = "select kind, id, data, updated_at from public.items where not deleted"
            params = []
            if args:
                q += " and kind = %s"
                params.append(args[0])
            for kind, id_, data, upd in c.execute(q + " order by kind, updated_at", params):
                print(kind, id_, json.dumps(data, ensure_ascii=False), upd.isoformat(timespec="seconds"))
        elif cmd == "note":
            now = dt.datetime.now().astimezone().isoformat()
            put(c, "note", {"title": args[0], "body": args[1] if len(args) > 1 else "", "updatedAt": now})
        elif cmd == "chore":
            now = dt.datetime.now().isoformat()
            put(c, "chore", {"title": args[0], "note": "", "createdAt": now,
                             "perDay": int(args[1]) if len(args) > 1 else 2,
                             "doneAt": None, "snoozedUntil": None})
        elif cmd == "task":
            minutes = None
            if len(args) > 2:
                h, m = args[2].split(":")
                minutes = int(h) * 60 + int(m)
            put(c, "task", {"title": args[0], "note": "", "startDate": args[1], "minutes": minutes,
                            "repeat": "none", "interval": 1, "weekdays": [], "dayOfMonth": None,
                            "carryOver": None, "doneDates": [], "remindBefore": 0})
        elif cmd == "put":
            put(c, args[0], json.loads(args[1]))
        elif cmd == "delete":
            n = c.execute("update public.items set deleted = true, data = null where id = %s", (args[0],)).rowcount
            print("gelöscht:", n)
        else:
            sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
