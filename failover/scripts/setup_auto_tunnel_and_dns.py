#!/usr/bin/env python3
"""
setup_auto_tunnel_and_dns.py - End-to-End Cloudflare Automation Tool

Automates:
1. Creating a new Cloudflare Tunnel for Tencent Standby (if not exists) & updating .env
2. Migrating all existing subdomains from direct tunnel CNAMEs to the Single Master Pointer (origin.homelab.faisalaffan.com)
"""

import sys
import os
import json
import base64
import urllib.request
import urllib.error
from pathlib import Path

# ANSI Color codes
GREEN = "\033[92m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

ENV_PATH = Path(__file__).resolve().parent.parent.parent / ".env"

def load_dotenv():
    if ENV_PATH.is_file():
        with open(ENV_PATH, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip("'\"")
                if k and k not in os.environ:
                    os.environ[k] = v

load_dotenv()

API_TOKEN = os.environ.get("CLOUDFLARE_API_TOKEN", "").strip()
GLOBAL_KEY = os.environ.get("CLOUDFLARE_API_KEY", "").strip()
CF_EMAIL = os.environ.get("CLOUDFLARE_EMAIL", "faisallionel@gmail.com").strip()
ZONE_ID = os.environ.get("CLOUDFLARE_ZONE_ID", "").strip()
ACCOUNT_ID = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
HOMELAB_UUID = os.environ.get("CLOUDFLARE_HOMELAB_TUNNEL_UUID", "005b8e0c-2069-47f0-94b8-12899a9dac50").strip()
MASTER_RECORD = os.environ.get("CLOUDFLARE_MASTER_ORIGIN_RECORD", "origin.homelab.faisalaffan.com").strip()

def cf_request(method, url, payload=None):
    headers = {
        "Content-Type": "application/json"
    }
    if GLOBAL_KEY and CF_EMAIL:
        headers["X-Auth-Key"] = GLOBAL_KEY
        headers["X-Auth-Email"] = CF_EMAIL
    else:
        headers["Authorization"] = f"Bearer {API_TOKEN}"

    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        try:
            return json.loads(err_msg)
        except Exception:
            return {"success": False, "errors": [{"message": err_msg}]}
    except Exception as e:
        return {"success": False, "errors": [{"message": str(e)}]}

def update_env_file(key, value):
    """Update or append a key-value pair in .env"""
    if not ENV_PATH.is_file():
        return
    with open(ENV_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    found = False
    new_lines = []
    for line in lines:
        if line.strip().startswith(f"{key}="):
            new_lines.append(f"{key}={value}\n")
            found = True
        else:
            new_lines.append(line)

    if not found:
        new_lines.append(f"{key}={value}\n")

    with open(ENV_PATH, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print(f"  {GREEN}✔ Updated .env: {key}={value}{RESET}")

def create_or_get_tencent_tunnel(tunnel_name="k3s-standby-tencent"):
    print(f"\n{BOLD}=========================================================={RESET}")
    print(f"1. Cloudflare Standby Tunnel Automation")
    print(f"Target Account: {ACCOUNT_ID}")
    print(f"Tunnel Name   : {tunnel_name}")
    print(f"{BOLD}=========================================================={RESET}")

    # Check existing tunnels
    list_url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/cfd_tunnel?is_deleted=false"
    res = cf_request("GET", list_url)
    if not res.get("success"):
        print(f"{RED}❌ Error querying tunnels: {res.get('errors')}{RESET}")
        return None

    existing = [t for t in res.get("result", []) if t.get("name") == tunnel_name]
    if existing:
        tunnel_id = existing[0]["id"]
        print(f"{GREEN}ℹ️  Tunnel '{tunnel_name}' already exists (ID: {tunnel_id}){RESET}")
        update_env_file("CLOUDFLARE_TENCENT_TUNNEL_UUID", tunnel_id)
        return tunnel_id

    # Create new tunnel
    print(f"{YELLOW}⏳ Tunnel '{tunnel_name}' not found. Creating new Cloudflare Tunnel...{RESET}")
    secret = base64.b64encode(os.urandom(32)).decode("utf-8")
    create_url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/cfd_tunnel"
    payload = {
        "name": tunnel_name,
        "tunnel_secret": secret,
        "config_src": "cloudflare"
    }
    create_res = cf_request("POST", create_url, payload)
    if not create_res.get("success"):
        print(f"{RED}❌ Failed to create tunnel: {create_res.get('errors')}{RESET}")
        return None

    tunnel_data = create_res.get("result", {})
    tunnel_id = tunnel_data.get("id")
    print(f"{GREEN}✅ SUCCESS: Created Tunnel '{tunnel_name}'!{RESET}")
    print(f"  Tunnel UUID: {BOLD}{tunnel_id}{RESET}")

    # Fetch token
    token_url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/cfd_tunnel/{tunnel_id}/token"
    token_res = cf_request("GET", token_url)
    if token_res.get("success"):
        token_str = token_res.get("result")
        update_env_file("CLOUDFLARE_TENCENT_TUNNEL_TOKEN", token_str)

    update_env_file("CLOUDFLARE_TENCENT_TUNNEL_UUID", tunnel_id)
    return tunnel_id

def migrate_subdomains_to_master(dry_run=False):
    print(f"\n{BOLD}=========================================================={RESET}")
    print(f"2. Subdomains Migration to Single Master Pointer")
    print(f"Master Pointer: {BOLD}{MASTER_RECORD}{RESET}")
    print(f"Current Target: {HOMELAB_UUID}.cfargotunnel.com")
    print(f"Mode          : {YELLOW}DRY RUN (Simulasi){RESET}" if dry_run else f"{GREEN}APPLY (Eksekusi Nyata){RESET}")
    print(f"{BOLD}=========================================================={RESET}")

    # Fetch all CNAME records
    list_url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records?type=CNAME&per_page=100"
    res = cf_request("GET", list_url)
    if not res.get("success"):
        print(f"{RED}❌ Failed to fetch DNS records: {res.get('errors')}{RESET}")
        return

    records = res.get("result", [])
    # Find records pointing directly to Homelab tunnel UUID, except the master record itself!
    targets = [
        r for r in records 
        if HOMELAB_UUID in r.get("content", "") and r.get("name") != MASTER_RECORD and r.get("name") != "origin.faisalaffan.com"
    ]

    print(f"Found {BOLD}{len(targets)}{RESET} subdomains currently pointing directly to Homelab tunnel:\n")
    for r in targets:
        print(f"  - {BOLD}{r['name']}{RESET} -> {r['content']}")

    if dry_run:
        print(f"\n{YELLOW}[DRY-RUN] Tidak ada perubahan yang dilakukan. Jalankan dengan argument '--apply' untuk mengeksekusi.{RESET}")
        return

    print(f"\n{YELLOW}Memulai migrasi {len(targets)} record ke '{MASTER_RECORD}'...{RESET}\n")
    success_count = 0
    for r in targets:
        patch_url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records/{r['id']}"
        patch_payload = {
            "type": "CNAME",
            "name": r["name"],
            "content": MASTER_RECORD,
            "proxied": True,
            "comment": "Managed by Single Master Pointer (Failover DR)"
        }
        p_res = cf_request("PATCH", patch_url, patch_payload)
        if p_res.get("success"):
            print(f"  {GREEN}✔ {r['name']} ➔ {MASTER_RECORD}{RESET}")
            success_count += 1
        else:
            print(f"  {RED}❌ Failed {r['name']}: {p_res.get('errors')}{RESET}")

    print(f"\n{GREEN}✅ Migrasi selesai: {success_count}/{len(targets)} record berhasil dialihkan ke Master Pointer!{RESET}")
    print(f"Mulai sekarang, ketika Anda switch 'origin', semua {success_count} subdomain otomatis beralih!")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [--check | --create-tunnel | --migrate-dns-dryrun | --migrate-dns-apply | --all]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "--check":
        print(f"Checking credentials...")
        list_url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records?name={MASTER_RECORD}"
        res = cf_request("GET", list_url)
        print(f"Master Record '{MASTER_RECORD}' status: {'FOUND' if res.get('result') else 'NOT FOUND'}")
        migrate_subdomains_to_master(dry_run=True)
    elif cmd == "--create-tunnel":
        create_or_get_tencent_tunnel()
    elif cmd == "--migrate-dns-dryrun":
        migrate_subdomains_to_master(dry_run=True)
    elif cmd == "--migrate-dns-apply":
        migrate_subdomains_to_master(dry_run=False)
    elif cmd == "--all":
        create_or_get_tencent_tunnel()
        migrate_subdomains_to_master(dry_run=False)
    else:
        print(f"{RED}Unknown command: {cmd}{RESET}")

if __name__ == "__main__":
    main()
