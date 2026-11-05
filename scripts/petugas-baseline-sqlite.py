"""Closed-development-profile backup/preflight. Never opens the daily database."""
import argparse
from contextlib import closing
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import os
import sqlite3
import winreg


def digest(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    with path.open("x", encoding="utf-8") as out:
        json.dump(value, out, indent=2, ensure_ascii=False)


def snapshot(db):
    tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    result = {"version": db.execute("PRAGMA user_version").fetchone()[0],
              "integrity": [r[0] for r in db.execute("PRAGMA integrity_check")],
              "fk": list(db.execute("PRAGMA foreign_key_check")), "counts": {}, "fingerprints": {}, "dirty": {}}
    for table in tables:
        name = '"' + table.replace('"', '""') + '"'
        rows = list(db.execute("SELECT * FROM " + name))
        result["counts"][table] = len(rows)
        result["fingerprints"][table] = digest("\n".join(sorted(json.dumps(list(r), ensure_ascii=False, separators=(",", ":")) for r in rows)).encode())
        columns = [r[1] for r in db.execute("PRAGMA table_info(" + name + ")")]
        if "is_sync_dirty" in columns:
            result["dirty"][table] = db.execute("SELECT count(*) FROM " + name + " WHERE is_sync_dirty!=0").fetchone()[0]
    result["schema"] = list(db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name"))
    result["genders"] = [dict(zip(("id", "uuid", "status", "dirty", "deleted"), row)) for row in db.execute("SELECT id,uuid,status,is_sync_dirty,deleted_at FROM jenis_kelamin ORDER BY id")]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--verify-after", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    receipt = Path(args.receipt).resolve(strict=True)
    assert receipt.is_relative_to(repo / ".local"), "Receipt must be workspace-owned"
    profile = json.loads((repo / ".local/notarisdev-profile.json").read_text(encoding="utf-8-sig"))
    generation = profile["generation"]
    assert profile["database"] == "notarisdev" and profile["port"] == 5432 and profile["fixture"] == "smoke-v1"
    assert len(generation) == 32 and all(c in "0123456789abcdef" for c in generation)
    target = Path(os.environ["APPDATA"]) / "com.notaris/frontend_notaris/notarisdev" / generation / "offline.sqlite"
    assert target.is_file() and target.resolve() == target
    for component in (target, *target.parents):
        assert not component.is_symlink() and not component.is_junction(), "Linked target refused"
    for suffix in ("-wal", "-shm", "-journal"):
        assert not Path(str(target) + suffix).exists(), "Sidecar found: stop; no checkpoint or main-only copy"
    # Deny other source writers at the OS level throughout read-only inspection/backup.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.CreateFileW(str(target), 0x80000000, 1, None, 3, 0x80, None)
    assert handle != ctypes.c_void_p(-1).value, "Source busy: cannot acquire read handle denying writers"
    try:
        before = {"sha256": digest(target.read_bytes()), "size": target.stat().st_size, "mtime_ns": target.stat().st_mtime_ns}
        with closing(sqlite3.connect(target.as_uri() + "?mode=ro&immutable=1", uri=True)) as source:
            source.execute("PRAGMA query_only=ON")
            inventory = snapshot(source)
            assert inventory["version"] == 13 and inventory["integrity"] == ["ok"] and not inventory["fk"]
            assert sum(inventory["dirty"].values()) == 0, "Dirty rows require review"
            if args.verify_after:
                prior = json.loads((receipt / "preparation.json").read_text(encoding="utf-8"))
                allowed = {"petugas", "petugas_identity_map", "petugas_sync_feed", "petugas_sync_journal", "petugas_gender_reference", "sqlite_sequence"}
                for table, value in prior["inventory"]["fingerprints"].items():
                    if table not in allowed:
                        assert inventory["fingerprints"][table] == value, "Unexpected existing-data change: " + table
                assert inventory["schema"] == [tuple(row) for row in prior["inventory"]["schema"]]
                for table in ("petugas", "petugas_identity_map", "petugas_sync_journal"):
                    assert inventory["counts"][table] == 4
                assert source.execute("SELECT scope,cursor,blocked FROM petugas_sync_feed").fetchall() == [(prior["scope"], 4, None)]
                assert source.execute("SELECT count(*) FROM petugas_sync_journal WHERE pending IS NOT NULL OR row_version!=1 OR row_version IS NULL").fetchone()[0] == 0
                assert source.execute("SELECT count(*) FROM petugas WHERE status!=1 OR deleted_at IS NOT NULL").fetchone()[0] == 0
                assert source.execute("SELECT count(*) FROM petugas_gender_reference WHERE scope=? AND local_uuid='notarisdev-smoke-gender-11' AND server_id=11 AND state='verified'", (prior["scope"],)).fetchone()[0] == 1
                with closing(sqlite3.connect(Path(prior["backup"]["path"]).as_uri() + "?mode=ro&immutable=1", uri=True)) as original:
                    before_sequence = dict(original.execute("SELECT name,seq FROM sqlite_sequence"))
                after_sequence = dict(source.execute("SELECT name,seq FROM sqlite_sequence"))
                assert {k: v for k, v in after_sequence.items() if k != "petugas"} == before_sequence
                result = {"status": "postcheck_verified", "source": before, "inventory": inventory}
                output = receipt / "sqlite-postcheck.json"
            else:
                for table in ("petugas", "petugas_identity_map", "petugas_sync_journal", "petugas_sync_feed", "petugas_sync_conflict", "petugas_gender_reference", "petugas_user_reference", "transaksis", "transaksi_details", "transaksi_proses", "transaksi_proses_riwayat", "transaksi_riwayat_pembayaran"):
                    assert inventory["counts"][table] == 0, "Expected empty reviewed table: " + table
                assert inventory["counts"]["pemohons"] == 20
                assert {"id": 1, "uuid": "notarisdev-smoke-gender-11", "status": 1, "dirty": 0, "deleted": None} in inventory["genders"]
                audit = json.loads((repo / ".local/petugas-existing-sqlite-audit-20261102/sqlite-audit.json").read_text(encoding="utf-8"))
                assert before["sha256"] == audit["after"]["sha256"], "Source changed since reviewed audit"
                backup = receipt / "before-import.sqlite"
                assert not backup.exists()
                with closing(sqlite3.connect(backup)) as destination:
                    source.backup(destination)
                    verified = snapshot(destination)
                assert verified == inventory, "Backup snapshot differs"
                with closing(sqlite3.connect(backup.as_uri() + "?mode=ro&immutable=1", uri=True)) as reopened:
                    assert snapshot(reopened) == inventory, "Reopened backup differs"
                # No device service/old Petugas scope exists. Derive, document and retain
                # one stable binding from the real machine + exact existing profile.
                with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Cryptography", 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY) as key:
                    machine = winreg.QueryValueEx(key, "MachineGuid")[0].strip().lower()
                assert machine
                material = json.dumps(["notaris-petugas-profile-v1", machine, generation, str(target).casefold()], separators=(",", ":"))
                device = "ndpetugas-" + digest(material.encode())[:32]
                identity = {"kind": "notaris-petugas-profile-v1", "generation": generation, "database_path": str(target), "device_id": device, "derivation": "sha256(namespace, Windows MachineGuid, generation, casefold canonical path); raw machine ID not retained", "machine_fingerprint": digest(machine.encode())}
                identity_path = repo / (".local/notarisdev-" + generation) / "petugas-device.json"
                if identity_path.exists():
                    assert json.loads(identity_path.read_text(encoding="utf-8")) == identity, "Device binding changed: stop"
                else:
                    save(identity_path, identity)
                scope = json.dumps(["http://127.0.0.1:8081/api/v1", "notarisdev", generation, 2001, device, str(target)], separators=(",", ":"))
                result = {"kind": "existing-petugas-baseline-v1", "status": "backup_verified_awaiting_http_preflight", "database_path": str(target), "generation": generation, "account_id": 2001, "group_id": 11, "device_id": device, "scope": scope, "device_manifest": str(identity_path), "source": before, "inventory": inventory, "backup": {"path": str(backup), "sha256": digest(backup.read_bytes()), "verified_reopened": True, "restore_readiness": "API backup reopened read-only; schema/integrity/FK/counts/all-table fingerprints equal source; no restore performed"}}
                output = receipt / "preparation.json"
        after = {"sha256": digest(target.read_bytes()), "size": target.stat().st_size, "mtime_ns": target.stat().st_mtime_ns}
        assert before == after, "Source changed during backup/audit; stop"
        assert not any(Path(str(target) + suffix).exists() for suffix in ("-wal", "-shm", "-journal"))
        result["source_unchanged"] = True
        save(output, result)
        print(json.dumps({"status": result["status"], "receipt": str(receipt), "source_unchanged": True}))
    finally:
        kernel.CloseHandle(handle)


if __name__ == "__main__":
    main()
