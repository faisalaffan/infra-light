#!/usr/bin/env python3
"""
Pull all secrets stored in HashiCorp Vault and export them as .env files.
"""

import os
import sys
import json
import urllib.request
import urllib.error
from datetime import datetime

def resolve_vault_token():
    token = os.getenv("VAULT_TOKEN")
    if token:
        return token
    sealed_token_path = os.path.join(os.path.dirname(__file__), "..", "SEALED_TOKEN_VAULT.md")
    if os.path.exists(sealed_token_path):
        try:
            with open(sealed_token_path, "r", encoding="utf-8") as f:
                for line in f:
                    if "Initial Root Token:" in line:
                        return line.split("Initial Root Token:")[1].strip()
        except Exception:
            pass
    return ""

VAULT_ADDR = os.getenv("VAULT_ADDR", "http://10.43.223.184:8200").rstrip("/")
VAULT_TOKEN = resolve_vault_token()
OUTPUT_BASE = os.getenv("OUTPUT_DIR", "/home/it-helpdesk/vault_envs")

def vault_request(endpoint, method="GET"):
    url = f"{VAULT_ADDR}/v1/{endpoint}"
    req = urllib.request.Request(
        url,
        headers={"X-Vault-Token": VAULT_TOKEN},
        method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return None
    except Exception as e:
        print(f"Error accessing {endpoint}: {e}", file=sys.stderr)
        return None

def list_keys_kv2(mount, subpath=""):
    mount_clean = mount.strip("/")
    url_path = f"{mount_clean}/metadata/{subpath}"
    res = vault_request(f"{url_path}?list=true")
    if not res:
        res = vault_request(url_path, method="LIST")
    if not res:
        return []

    keys = res.get("data", {}).get("keys", [])
    results = []
    for key in keys:
        full = f"{subpath}{key}"
        if key.endswith("/"):
            results.extend(list_keys_kv2(mount, full))
        else:
            results.append(full)
    return results

def list_keys_kv1(mount, subpath=""):
    mount_clean = mount.strip("/")
    url_path = f"{mount_clean}/{subpath}"
    res = vault_request(f"{url_path}?list=true")
    if not res:
        res = vault_request(url_path, method="LIST")
    if not res:
        return []

    keys = res.get("data", {}).get("keys", [])
    results = []
    for key in keys:
        full = f"{subpath}{key}"
        if key.endswith("/"):
            results.extend(list_keys_kv1(mount, full))
        else:
            results.append(full)
    return results

def get_secret_data(mount, path, version="2"):
    mount_clean = mount.strip("/")
    if version == "2":
        res = vault_request(f"{mount_clean}/data/{path}")
        if res and "data" in res and "data" in res["data"]:
            return res["data"]["data"], res["data"].get("metadata", {})
        return None, None
    else:
        res = vault_request(f"{mount_clean}/{path}")
        if res and "data" in res:
            return res["data"], {}
        return None, None

def format_env_value(val):
    if val is None:
        return ""
    if not isinstance(val, str):
        val = str(val)
    # Check if value needs quoting
    needs_quotes = (
        " " in val or
        "\t" in val or
        "#" in val or
        "$" in val or
        "\n" in val or
        "\"" in val or
        "'" in val or
        "=" in val or
        val == ""
    )
    if needs_quotes:
        escaped = val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    return val

def export_all():
    print(f"Connecting to Vault at {VAULT_ADDR}...")
    mounts_res = vault_request("sys/mounts")
    if not mounts_res:
        print("Failed to get mounts from Vault. Check token or connectivity.", file=sys.stderr)
        sys.exit(1)

    mount_dict = mounts_res.get("data", mounts_res)
    discovered = []

    for mount_name, mount_info in mount_dict.items():
        if isinstance(mount_info, dict) and mount_info.get("type") == "kv":
            opts = mount_info.get("options") or {}
            version = opts.get("version", "1")
            clean_mount = mount_name.strip("/")
            print(f"\nScanning mount: '{clean_mount}' (KV v{version})...")
            if version == "2":
                keys = list_keys_kv2(clean_mount)
            else:
                keys = list_keys_kv1(clean_mount)

            for key in sorted(keys):
                discovered.append((clean_mount, version, key))

    print(f"\nTotal secrets discovered: {len(discovered)}")
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    exported_files = []

    for mount, ver, key in discovered:
        sec_data, meta = get_secret_data(mount, key, ver)
        if sec_data is None:
            print(f"  [WARN] Could not retrieve data for {mount}/{key}")
            continue

        # Target file path
        # If mount is 'secret', organize directly under OUTPUT_BASE/<key>.env
        # If mount is something else (like 'DEVOPS_CONFIG'), OUTPUT_BASE/<mount>/<key>.env
        if mount == "secret":
            rel_file = f"{key}.env"
        else:
            rel_file = f"{mount}/{key}.env"

        target_path = os.path.join(OUTPUT_BASE, rel_file)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        lines = [
            f"# ============================================================",
            f"# Vault Secret: {mount}/{key}",
            f"# Extracted at: {now_str}",
            f"# Total keys:   {len(sec_data)}",
        ]
        if meta:
            created_time = meta.get("created_time")
            ver_num = meta.get("version")
            if created_time:
                lines.append(f"# Vault Version: v{ver_num} (Created: {created_time})")
        lines.append(f"# ============================================================\n")

        for k in sorted(sec_data.keys()):
            v = sec_data[k]
            formatted_v = format_env_value(v)
            lines.append(f"{k}={formatted_v}")

        lines.append("")  # trailing newline
        content = "\n".join(lines)

        with open(target_path, "w", encoding="utf-8") as f:
            f.write(content)

        print(f"  ✓ Saved {len(sec_data):3d} keys -> {target_path}")
        exported_files.append({
            "vault_path": f"{mount}/{key}",
            "file_path": target_path,
            "keys_count": len(sec_data),
            "keys": sorted(list(sec_data.keys()))
        })

    # Save manifest
    manifest_path = os.path.join(OUTPUT_BASE, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({
            "extracted_at": now_str,
            "vault_addr": VAULT_ADDR,
            "total_secrets": len(exported_files),
            "secrets": exported_files
        }, f, indent=2)

    print(f"\nManifest saved to {manifest_path}")
    print("\nAll .env files successfully pulled from Vault!")

if __name__ == "__main__":
    export_all()
