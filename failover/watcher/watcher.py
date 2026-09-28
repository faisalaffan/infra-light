#!/usr/bin/env python3
"""
watcher.py - External Heartbeat Monitor & Failover Alerting Daemon
NOTE: This script is intended to run OUTSIDE the homelab (e.g. lightweight VPS, GitHub Actions, AWS Lambda).
"""

import os
import sys
import time
import requests
import json
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

HEALTH_ENDPOINT = os.getenv("HEALTH_ENDPOINT", "https://health.homelab.example.com/ping")
CHECK_INTERVAL_SECONDS = int(os.getenv("CHECK_INTERVAL_SECONDS", "30"))
FAILURE_THRESHOLD = int(os.getenv("FAILURE_THRESHOLD", "5"))
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

def send_telegram_alert(message: str):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logging.warning("Telegram credentials not configured. Alert not sent to Telegram.")
        return

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "Markdown"
    }
    try:
        resp = requests.post(url, json=payload, timeout=10)
        resp.raise_for_status()
    except Exception as e:
        logging.error(f"Failed to send Telegram alert: {e}")

def check_health() -> bool:
    try:
        resp = requests.get(HEALTH_ENDPOINT, timeout=10)
        return resp.status_code == 200
    except Exception as e:
        logging.debug(f"Health check failed: {e}")
        return False

def main():
    consecutive_failures = 0
    alert_triggered = False

    logging.info(f"Watcher started. Monitoring {HEALTH_ENDPOINT} every {CHECK_INTERVAL_SECONDS}s (Threshold: {FAILURE_THRESHOLD})")

    while True:
        is_healthy = check_health()

        if is_healthy:
            if consecutive_failures > 0:
                logging.info(f"Homelab recovered. Resetting failure counter.")
                if alert_triggered:
                    send_telegram_alert("🟢 *Homelab Recovered*: Baremetal node is back online.")
                    alert_triggered = False
            consecutive_failures = 0
        else:
            consecutive_failures += 1
            logging.warning(f"Health check failure {consecutive_failures}/{FAILURE_THRESHOLD}")

            if consecutive_failures >= FAILURE_THRESHOLD and not alert_triggered:
                alert_triggered = True
                alert_msg = (
                    "🚨 *HOMELAB OUTAGE DETECTED!*\n\n"
                    f"Health check failed {consecutive_failures} times consecutively.\n"
                    "Baremetal host appears down or unreachable.\n\n"
                    "⚠️ *Action Required:*\n"
                    "1. Verify baremetal power & network connectivity.\n"
                    "2. To trigger AWS Failover, run the failover pipeline or execute:\n"
                    "`cd /home/it-helpdesk/DEVOPS/failover/terraform/envs/prod && terraform apply`\n"
                    "3. Review runbook: `failover/runbooks/failover.md`"
                )
                logging.error("Triggering Outage Alert to Operator...")
                send_telegram_alert(alert_msg)

        time.sleep(CHECK_INTERVAL_SECONDS)

if __name__ == "__main__":
    main()
