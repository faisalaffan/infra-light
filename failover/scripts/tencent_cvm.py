#!/usr/bin/env python3
"""
tencent_cvm.py - Lightweight Tencent Cloud CVM Controller
Uses standard Python library (no external dependencies) with TC3-HMAC-SHA256.
Supports: describe, start, stop (with STOP_CHARGING for zero-cost idle), and status.
"""
import sys
import os
import json
import time
import hmac
import hashlib
from datetime import datetime, timezone
import urllib.request
import urllib.error

def sign(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def get_signature_key(key, date, service):
    k_date = sign(("TC3" + key).encode("utf-8"), date)
    k_service = sign(k_date, service)
    k_signing = sign(k_service, "tc3_request")
    return k_signing

def call_cvm_api(secret_id, secret_key, region, action, payload=None):
    service = "cvm"
    host = "cvm.tencentcloudapi.com"
    version = "2017-03-12"
    algorithm = "TC3-HMAC-SHA256"
    
    if payload is None:
        payload = {}
    payload_str = json.dumps(payload)
    
    now = datetime.now(timezone.utc)
    timestamp = int(now.timestamp())
    date = now.strftime("%Y-%m-%d")
    
    http_request_method = "POST"
    canonical_uri = "/"
    canonical_querystring = ""
    canonical_headers = (
        f"content-type:application/json; charset=utf-8\n"
        f"host:{host}\n"
        f"x-tc-action:{action.lower()}\n"
    )
    signed_headers = "content-type;host;x-tc-action"
    hashed_request_payload = hashlib.sha256(payload_str.encode("utf-8")).hexdigest()
    
    canonical_request = (
        f"{http_request_method}\n"
        f"{canonical_uri}\n"
        f"{canonical_querystring}\n"
        f"{canonical_headers}\n"
        f"{signed_headers}\n"
        f"{hashed_request_payload}"
    )
    
    credential_scope = f"{date}/{service}/tc3_request"
    hashed_canonical_request = hashlib.sha256(canonical_request.encode("utf-8")).hexdigest()
    string_to_sign = (
        f"{algorithm}\n"
        f"{timestamp}\n"
        f"{credential_scope}\n"
        f"{hashed_canonical_request}"
    )
    
    secret_signing = get_signature_key(secret_key, date, service)
    signature = hmac.new(secret_signing, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    
    authorization = (
        f"{algorithm} "
        f"Credential={secret_id}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, "
        f"Signature={signature}"
    )
    
    headers = {
        "Authorization": authorization,
        "Content-Type": "application/json; charset=utf-8",
        "Host": host,
        "X-TC-Action": action,
        "X-TC-Timestamp": str(timestamp),
        "X-TC-Version": version,
        "X-TC-Region": region,
    }
    
    req = urllib.request.Request(
        f"https://{host}",
        data=payload_str.encode("utf-8"),
        headers=headers,
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = resp.read().decode("utf-8")
            return json.loads(resp_body)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        raise RuntimeError(f"API Error ({e.code}): {error_body}")
    except Exception as e:
        raise RuntimeError(f"Request failed: {e}")

def load_env_file(filepath):
    """Simple parser for .env file if environment variables aren't already exported"""
    if not os.path.isfile(filepath):
        return
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            v = v.strip().strip("'\"")
            if k not in os.environ:
                os.environ[k] = v

def main():
    # Load .env if present
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    env_file = os.path.join(repo_root, ".env")
    load_env_file(env_file)
    
    secret_id = os.getenv("TENCENTCLOUD_SECRET_ID", "").strip()
    secret_key = os.getenv("TENCENTCLOUD_SECRET_KEY", "").strip()
    region = os.getenv("TENCENTCLOUD_REGION", "ap-singapore").strip()
    
    if not secret_id or not secret_key:
        print("ERROR: TENCENTCLOUD_SECRET_ID and TENCENTCLOUD_SECRET_KEY must be set.", file=sys.stderr)
        sys.exit(1)
        
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    target_instance_id = sys.argv[2] if len(sys.argv) > 2 else ""
    
    if cmd in ("status", "describe", "list"):
        payload = {}
        if target_instance_id:
            payload["InstanceIds"] = [target_instance_id]
        else:
            # Query instances with tag Role or by environment
            payload["Filters"] = [
                {"Name": "tag-key", "Values": ["Role", "Environment"]}
            ]
            
        data = call_cvm_api(secret_id, secret_key, region, "DescribeInstances", payload)
        response = data.get("Response", {})
        if "Error" in response:
            print(f"Tencent API Error: {response['Error'].get('Message')}", file=sys.stderr)
            sys.exit(1)
            
        instances = response.get("InstanceSet", [])
        if not instances and not target_instance_id:
            # Fallback to list all instances in region
            data = call_cvm_api(secret_id, secret_key, region, "DescribeInstances", {"Limit": 20})
            instances = data.get("Response", {}).get("InstanceSet", [])
            
        if not instances:
            print(json.dumps({"status": "NOT_FOUND", "instances": []}, indent=2))
            sys.exit(0)
            
        summary = []
        for inst in instances:
            summary.append({
                "InstanceId": inst.get("InstanceId"),
                "InstanceName": inst.get("InstanceName"),
                "InstanceState": inst.get("InstanceState"),
                "PublicIpAddresses": inst.get("PublicIpAddresses", []),
                "PrivateIpAddresses": inst.get("PrivateIpAddresses", []),
                "InstanceType": inst.get("InstanceType"),
                "CreatedTime": inst.get("CreatedTime"),
                "Zone": inst.get("Placement", {}).get("Zone"),
            })
            
        first_state = summary[0]["InstanceState"] if summary else "NOT_FOUND"
        output = {
            "status": first_state,
            "region": region,
            "count": len(summary),
            "instances": summary
        }
        print(json.dumps(output, indent=2))
        
    elif cmd == "start":
        if not target_instance_id:
            # Discover target instance
            data = call_cvm_api(secret_id, secret_key, region, "DescribeInstances", {"Limit": 10})
            instances = data.get("Response", {}).get("InstanceSet", [])
            if not instances:
                print("ERROR: No instances found to start.", file=sys.stderr)
                sys.exit(1)
            target_instance = instances[0]
            target_instance_id = target_instance["InstanceId"]
            state = target_instance.get("InstanceState")
            if state in ("STARTING", "RUNNING"):
                print(f"ℹ️  Instance {target_instance_id} is ALREADY {state}.")
                sys.exit(0)
            
        print(f"Starting instance {target_instance_id} in {region}...")
        res = call_cvm_api(secret_id, secret_key, region, "StartInstances", {"InstanceIds": [target_instance_id]})
        print(json.dumps(res.get("Response", {}), indent=2))
        
    elif cmd == "stop":
        if not target_instance_id:
            data = call_cvm_api(secret_id, secret_key, region, "DescribeInstances", {"Limit": 10})
            instances = data.get("Response", {}).get("InstanceSet", [])
            if not instances:
                print("ERROR: No instances found to stop.", file=sys.stderr)
                sys.exit(1)
            target_instance = instances[0]
            target_instance_id = target_instance["InstanceId"]
            state = target_instance.get("InstanceState")
            if state in ("STOPPING", "STOPPED"):
                print(f"✔ Instance {target_instance_id} is ALREADY {state} (Zero Compute Billing).")
                sys.exit(0)
            
        # IMPORTANT: StopType="SOFT_FIRST", StoppedMode="STOP_CHARGING" ensures $0 compute cost while idle!
        print(f"Stopping instance {target_instance_id} with StoppedMode=STOP_CHARGING (Zero Compute Billing)...")
        res = call_cvm_api(secret_id, secret_key, region, "StopInstances", {
            "InstanceIds": [target_instance_id],
            "StopType": "SOFT_FIRST",
            "StoppedMode": "STOP_CHARGING"
        })
        print(json.dumps(res.get("Response", {}), indent=2))
        
    else:
        print(f"Usage: {sys.argv[0]} [status|describe|start|stop] [instance_id]")
        sys.exit(1)

if __name__ == "__main__":
    main()
