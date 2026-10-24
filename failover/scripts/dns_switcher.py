#!/usr/bin/env python3
"""
dns_switcher.py - Cloudflare Single Master Pointer Failover Controller
Method 1: Single Master Pointer Pattern.

Switches a single master CNAME record (e.g. origin.homelab.faisalaffan.com)
between Homelab Tunnel and Standby (Tencent) Tunnel. All service subdomains
(app, api, grafana, *.domain) CNAME to this single record, enabling instant
global failover in seconds.
"""

import sys
import os
import json
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

def load_dotenv():
    """Load environment variables from root .env if not already set."""
    script_dir = Path(__file__).resolve().parent
    candidates = [
        script_dir.parent.parent / ".env",
        script_dir.parent / ".env",
        Path.cwd() / ".env"
    ]
    for env_path in candidates:
        if env_path.is_file():
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k and k not in os.environ:
                        os.environ[k] = v
            break

load_dotenv()

API_TOKEN = os.environ.get("CLOUDFLARE_API_TOKEN", "").strip()
GLOBAL_KEY = os.environ.get("CLOUDFLARE_API_KEY", "").strip()
CF_EMAIL = os.environ.get("CLOUDFLARE_EMAIL", "faisallionel@gmail.com").strip()
ZONE_ID = os.environ.get("CLOUDFLARE_ZONE_ID", "").strip()
FAILOVER_DOMAIN = os.environ.get("FAILOVER_DOMAIN", "homelab.faisalaffan.com").strip()
MASTER_RECORD = os.environ.get("CLOUDFLARE_MASTER_ORIGIN_RECORD", f"origin.{FAILOVER_DOMAIN}").strip()

HOMELAB_UUID = os.environ.get("CLOUDFLARE_HOMELAB_TUNNEL_UUID", "").strip()
TENCENT_UUID = os.environ.get("CLOUDFLARE_TENCENT_TUNNEL_UUID", "").strip()
if not TENCENT_UUID:
    # Fallback if named differently
    TENCENT_UUID = os.environ.get("CLOUDFLARE_VULTR_TUNNEL_UUID", "").strip()

def cf_api_request(method, endpoint, payload=None):
    if (not API_TOKEN and not GLOBAL_KEY) or not ZONE_ID:
        print(f"{RED}❌ Error: CLOUDFLARE_API_TOKEN (or CLOUDFLARE_API_KEY) and CLOUDFLARE_ZONE_ID must be set in .env{RESET}", file=sys.stderr)
        sys.exit(1)

    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}{endpoint}"
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
            err_json = json.loads(err_msg)
            errors = err_json.get("errors", [])
            print(f"{RED}❌ Cloudflare API Error ({e.code}): {errors}{RESET}", file=sys.stderr)
        except Exception:
            print(f"{RED}❌ Cloudflare API Error ({e.code}): {err_msg}{RESET}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"{RED}❌ Connection Error: {e}{RESET}", file=sys.stderr)
        sys.exit(1)

def find_master_record():
    resp = cf_api_request("GET", f"/dns_records?name={MASTER_RECORD}&type=CNAME")
    records = resp.get("result", [])
    if records:
        return records[0]
    return None

def get_target_hostname(target):
    target = target.lower()
    if target in ["homelab", "home", "primary"]:
        if not HOMELAB_UUID:
            print(f"{RED}❌ Error: CLOUDFLARE_HOMELAB_TUNNEL_UUID is not defined in .env{RESET}", file=sys.stderr)
            sys.exit(1)
        return f"{HOMELAB_UUID}.cfargotunnel.com", "Homelab Baremetal (Primary)"
    elif target in ["tencent", "cloud", "standby"]:
        if not TENCENT_UUID:
            print(f"{RED}❌ Error: CLOUDFLARE_TENCENT_TUNNEL_UUID is not defined in .env{RESET}", file=sys.stderr)
            sys.exit(1)
        return f"{TENCENT_UUID}.cfargotunnel.com", "Tencent Cloud Standby (Failover)"
    else:
        print(f"{RED}❌ Error: Unknown target '{target}'. Allowed options: 'homelab' or 'tencent'{RESET}", file=sys.stderr)
        sys.exit(1)

def action_status():
    print(f"\n{BOLD}=========================================================={RESET}")
    print(f"{BOLD}🌐 Cloudflare Single Master Pointer Status{RESET}")
    print(f"Master Record : {BOLD}{MASTER_RECORD}{RESET}")
    print(f"Domain Zone   : {ZONE_ID}")
    print(f"{BOLD}=========================================================={RESET}")

    rec = find_master_record()
    if not rec:
        print(f"{YELLOW}⚠️  Record {MASTER_RECORD} NOT FOUND in Cloudflare DNS.{RESET}")
        print(f"Run '{BOLD}./failover.sh switch homelab{RESET}' to create it automatically.")
        return

    content = rec.get("content", "")
    proxied = rec.get("proxied", False)
    rec_id = rec.get("id", "")

    status_tag = f"{YELLOW}UNKNOWN ({content}){RESET}"
    if HOMELAB_UUID and HOMELAB_UUID in content:
        status_tag = f"{GREEN}🟢 HOMELAB PRIMARY (Active){RESET}"
    elif TENCENT_UUID and TENCENT_UUID in content:
        status_tag = f"{BLUE}🔵 TENCENT STANDBY (Active){RESET}"

    proxy_tag = f"{YELLOW}🟧 Proxied (Orange Cloud){RESET}" if proxied else f"⚪ DNS-Only"

    print(f"Current Target : {BOLD}{content}{RESET}")
    print(f"Routing Status : {status_tag}")
    print(f"Proxy Mode     : {proxy_tag}")
    print(f"Record ID      : {rec_id}")
    print(f"{BOLD}=========================================================={RESET}\n")

def action_switch(target):
    new_content, target_label = get_target_hostname(target)
    rec = find_master_record()

    print(f"\n{BOLD}=========================================================={RESET}")
    print(f"🚀 Switching All CNAMEs via Master Record Pointer")
    print(f"Master Record : {BOLD}{MASTER_RECORD}{RESET}")
    print(f"Target Origin : {BOLD}{target_label}{RESET}")
    print(f"New CNAME Val : {new_content}")
    print(f"{BOLD}=========================================================={RESET}")

    if rec:
        current_content = rec.get("content", "")
        if current_content == new_content:
            print(f"{GREEN}✔ Record already points to {target_label}. No changes needed.{RESET}\n")
            return

        rec_id = rec["id"]
        payload = {
            "type": "CNAME",
            "name": MASTER_RECORD,
            "content": new_content,
            "proxied": True,
            "comment": f"Managed by Failover Single Master Pointer ({target})"
        }
        resp = cf_api_request("PATCH", f"/dns_records/{rec_id}", payload)
        if resp.get("success"):
            print(f"\n{GREEN}✅ SUCCESS! Master DNS record updated successfully!{RESET}")
            print(f"All subdomains (app, api, grafana, *) now point to: {BOLD}{target_label}{RESET}")
            print(f"Cloudflare Edge propagation time: ~5 to 15 seconds globally.\n")
        else:
            print(f"{RED}❌ Failed to update record: {resp}{RESET}\n")
            sys.exit(1)
    else:
        # Create record if not present
        print(f"{YELLOW}ℹ️  Master record does not exist yet. Creating new CNAME record...{RESET}")
        payload = {
            "type": "CNAME",
            "name": MASTER_RECORD,
            "content": new_content,
            "ttl": 1,
            "proxied": True,
            "comment": f"Managed by Failover Single Master Pointer ({target})"
        }
        resp = cf_api_request("POST", "/dns_records", payload)
        if resp.get("success"):
            print(f"\n{GREEN}✅ SUCCESS! Created master DNS record {MASTER_RECORD} pointing to {target_label}!{RESET}\n")
        else:
            print(f"{RED}❌ Failed to create record: {resp}{RESET}\n")
            sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [status | switch <homelab|tencent>]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd in ["status", "check"]:
        action_status()
    elif cmd in ["switch", "to"]:
        if len(sys.argv) < 3:
            print(f"{RED}❌ Error: Please specify target: 'homelab' or 'tencent'{RESET}")
            print(f"Example: {sys.argv[0]} switch tencent")
            sys.exit(1)
        action_switch(sys.argv[2].lower())
    else:
        print(f"{RED}❌ Unknown command: {cmd}. Available: status, switch{RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()
