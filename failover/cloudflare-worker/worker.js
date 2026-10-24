/**
 * Cloudflare Worker: Disaster Recovery Control Center (Mobile-Friendly Dashboard)
 * 
 * - Does NOT proxy user traffic (Zero risk of hitting 100k requests/day limit).
 * - Controls the Cloudflare Single Master Pointer DNS record via Cloudflare API.
 * - Controls Tencent Standby CVM lifecycle via GitHub Actions workflow_dispatch.
 * - Protected by PIN authentication.
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, X-Admin-Pin",
        },
      });
    }

    // Static Assets / Dashboard UI
    if (url.pathname === "/" || url.pathname === "/index.html") {
      return handleDashboardUI(request, env);
    }

    // API Routes
    if (url.pathname.startsWith("/api/")) {
      return handleApiRoutes(request, env, url);
    }

    return new Response("Not Found", { status: 404 });
  },
};

/**
 * Handle API Endpoints (/api/status, /api/switch, /api/compute)
 */
async function handleApiRoutes(request, env, url) {
  const pinHeader = request.headers.get("X-Admin-Pin") || url.searchParams.get("pin");
  const expectedPin = env.ADMIN_PIN || "2026";

  if (!pinHeader || pinHeader !== expectedPin) {
    return jsonResponse({ error: "Unauthorized: Invalid PIN" }, 401);
  }

  const CF_ZONE_ID = env.CLOUDFLARE_ZONE_ID;
  const MASTER_RECORD = env.CLOUDFLARE_MASTER_ORIGIN_RECORD || `origin.${env.FAILOVER_DOMAIN || "homelab.faisalaffan.com"}`;
  const HOMELAB_UUID = env.CLOUDFLARE_HOMELAB_TUNNEL_UUID;
  const TENCENT_UUID = env.CLOUDFLARE_TENCENT_TUNNEL_UUID;

  const cfHeaders = { "Content-Type": "application/json" };
  if (env.CLOUDFLARE_API_KEY && (env.CLOUDFLARE_EMAIL || env.GIT_EMAIL)) {
    cfHeaders["X-Auth-Key"] = env.CLOUDFLARE_API_KEY;
    cfHeaders["X-Auth-Email"] = env.CLOUDFLARE_EMAIL || env.GIT_EMAIL || "faisallionel@gmail.com";
  } else if (env.CLOUDFLARE_API_TOKEN) {
    cfHeaders["Authorization"] = `Bearer ${env.CLOUDFLARE_API_TOKEN}`;
  }
  const hasCFAuth = !!(cfHeaders["Authorization"] || cfHeaders["X-Auth-Key"]);

  // 1. GET /api/status - Query Cloudflare DNS & Current Origin
  if (url.pathname === "/api/status" && request.method === "GET") {
    try {
      if (!hasCFAuth || !CF_ZONE_ID) {
        return jsonResponse({ error: "Missing Cloudflare credentials (CLOUDFLARE_API_KEY or CLOUDFLARE_API_TOKEN) or CLOUDFLARE_ZONE_ID" }, 500);
      }

      const cfResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${MASTER_RECORD}&type=CNAME`, {
        headers: cfHeaders,
      });

      const cfData = await cfResp.json();
      if (!cfData.success) {
        return jsonResponse({ error: "Cloudflare API Error", details: cfData.errors }, 502);
      }

      const record = cfData.result && cfData.result[0];
      let currentOrigin = "UNKNOWN";
      let content = "Record Not Found";
      let proxied = false;

      if (record) {
        content = record.content;
        proxied = record.proxied;
        if (HOMELAB_UUID && content.includes(HOMELAB_UUID)) {
          currentOrigin = "HOMELAB";
        } else if (TENCENT_UUID && content.includes(TENCENT_UUID)) {
          currentOrigin = "TENCENT";
        }
      }

      return jsonResponse({
        masterRecord: MASTER_RECORD,
        currentOrigin,
        targetContent: content,
        proxied,
        recordId: record ? record.id : null,
        homelabUuid: HOMELAB_UUID ? `${HOMELAB_UUID.substring(0, 8)}...` : null,
        tencentUuid: TENCENT_UUID ? `${TENCENT_UUID.substring(0, 8)}...` : null,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  }

  // 2. POST /api/switch - Switch Master Pointer to Homelab or Tencent
  if (url.pathname === "/api/switch" && request.method === "POST") {
    try {
      const body = await request.json().catch(() => ({}));
      const target = (body.target || url.searchParams.get("target") || "").toLowerCase();

      let newContent = "";
      if (target === "homelab") {
        if (!HOMELAB_UUID) return jsonResponse({ error: "HOMELAB_UUID is not configured" }, 400);
        newContent = `${HOMELAB_UUID}.cfargotunnel.com`;
      } else if (target === "tencent") {
        if (!TENCENT_UUID) return jsonResponse({ error: "TENCENT_UUID is not configured" }, 400);
        newContent = `${TENCENT_UUID}.cfargotunnel.com`;
      } else {
        return jsonResponse({ error: "Invalid target. Specify 'homelab' or 'tencent'" }, 400);
      }

      // Check existing record
      const cfGet = await fetch(`https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${MASTER_RECORD}&type=CNAME`, {
        headers: cfHeaders,
      });
      const getJson = await cfGet.json();
      const existing = getJson.result && getJson.result[0];

      let updateResp;
      if (existing) {
        updateResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${existing.id}`, {
          method: "PATCH",
          headers: cfHeaders,
          body: JSON.stringify({
            type: "CNAME",
            name: MASTER_RECORD,
            content: newContent,
            proxied: true,
            comment: `Switched via DR Control Center (${target})`
          }),
        });
      } else {
        updateResp = await fetch(`https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records`, {
          method: "POST",
          headers: cfHeaders,
          body: JSON.stringify({
            type: "CNAME",
            name: MASTER_RECORD,
            content: newContent,
            ttl: 1,
            proxied: true,
            comment: `Created via DR Control Center (${target})`
          }),
        });
      }

      const updateJson = await updateResp.json();
      if (!updateJson.success) {
        return jsonResponse({ error: "Failed to update DNS record", details: updateJson.errors }, 502);
      }

      return jsonResponse({
        success: true,
        message: `Successfully switched all traffic to ${target.toUpperCase()}`,
        targetOrigin: target.toUpperCase(),
        newContent,
        timestamp: new Date().toISOString()
      });
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  }

  // 3. POST /api/compute - Trigger Start/Stop Tencent CVM via GitHub Actions
  if (url.pathname === "/api/compute" && request.method === "POST") {
    try {
      const body = await request.json().catch(() => ({}));
      const action = (body.action || "").toLowerCase(); // "start" or "stop"
      if (!["start", "stop"].includes(action)) {
        return jsonResponse({ error: "Invalid action. Use 'start' or 'stop'" }, 400);
      }

      const GITHUB_REPO = env.GITHUB_REPO || "faisalaffan/infra-light";
      const GITHUB_PAT = env.GITHUB_PAT;

      if (!GITHUB_PAT) {
        return jsonResponse({ error: "GITHUB_PAT is not configured in worker secrets" }, 500);
      }

      const ghResp = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/actions/workflows/dr-failover.yml/dispatches`, {
        method: "POST",
        headers: {
          "Accept": "application/vnd.github.v3+json",
          "Authorization": `Bearer ${GITHUB_PAT}`,
          "User-Agent": "DR-Failover-Worker-Controller"
        },
        body: JSON.stringify({
          ref: "main",
          inputs: {
            action: action,
            environment: "prod",
            provider: "tencent"
          }
        })
      });

      if (ghResp.status === 204) {
        return jsonResponse({
          success: true,
          message: `GitHub Action dispatched: ${action.toUpperCase()} Tencent CVM`,
          action,
          repo: GITHUB_REPO,
          timestamp: new Date().toISOString()
        });
      } else {
        const errDetail = await ghResp.text();
        return jsonResponse({ error: "GitHub dispatch failed", status: ghResp.status, details: errDetail }, 502);
      }
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  }

  return jsonResponse({ error: "Endpoint not found" }, 404);
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

/**
 * Mobile-First Responsive Modern Web Dashboard
 */
function handleDashboardUI(request, env) {
  const defaultMaster = env.CLOUDFLARE_MASTER_ORIGIN_RECORD || `origin.${env.FAILOVER_DOMAIN || "homelab.faisalaffan.com"}`;
  
  const html = `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>DR Failover Control Center</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #090d16;
      --card-bg: rgba(17, 24, 39, 0.75);
      --card-border: rgba(255, 255, 255, 0.08);
      --text: #f3f4f6;
      --text-muted: #9ca3af;
      --primary: #3b82f6;
      --primary-hover: #2563eb;
      --accent-home: #10b981;
      --accent-tencent: #0ea5e9;
      --accent-warn: #f59e0b;
      --accent-danger: #ef4444;
      --font-main: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      background-image: 
        radial-gradient(circle at 15% 15%, rgba(59, 130, 246, 0.12) 0%, transparent 40%),
        radial-gradient(circle at 85% 85%, rgba(16, 185, 129, 0.08) 0%, transparent 40%);
      color: var(--text);
      font-family: var(--font-main);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 16px;
      -webkit-tap-highlight-color: transparent;
    }

    .container {
      width: 100%;
      max-width: 480px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    header {
      text-align: center;
      padding: 12px 0 6px;
    }
    .header-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(59, 130, 246, 0.15);
      color: #93c5fd;
      border: 1px solid rgba(59, 130, 246, 0.3);
      padding: 4px 12px;
      border-radius: 9999px;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      margin-bottom: 8px;
    }
    h1 {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.02em;
      background: linear-gradient(135deg, #ffffff 30%, #94a3b8 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    .card {
      background: var(--card-bg);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid var(--card-border);
      border-radius: 18px;
      padding: 20px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
    }

    /* Status Card */
    .status-box {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .status-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .status-label {
      font-size: 12px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      font-weight: 600;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 700;
      box-shadow: 0 0 15px rgba(0,0,0,0.2);
    }
    .status-badge.homelab {
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.4);
    }
    .status-badge.tencent {
      background: rgba(14, 165, 233, 0.15);
      color: #38bdf8;
      border: 1px solid rgba(14, 165, 233, 0.4);
    }
    .status-badge.unknown {
      background: rgba(156, 163, 175, 0.15);
      color: #d1d5db;
      border: 1px solid rgba(156, 163, 175, 0.3);
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: currentColor;
      box-shadow: 0 0 8px currentColor;
      animation: pulse 2s infinite ease-in-out;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.85); }
    }

    .record-info {
      background: rgba(0, 0, 0, 0.25);
      border: 1px solid rgba(255, 255, 255, 0.05);
      border-radius: 12px;
      padding: 10px 14px;
      font-family: var(--font-mono);
      font-size: 12px;
      word-break: break-all;
      color: #cbd5e1;
    }
    .record-info span { color: var(--text-muted); font-size: 11px; display: block; margin-bottom: 2px; }

    /* Action Buttons */
    .actions-grid {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .btn {
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      width: 100%;
      padding: 15px 18px;
      border-radius: 14px;
      font-family: var(--font-main);
      font-size: 15px;
      font-weight: 600;
      border: none;
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .btn:active {
      transform: scale(0.98);
    }
    .btn-tencent {
      background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%);
      color: white;
      box-shadow: 0 4px 14px rgba(2, 132, 199, 0.35);
    }
    .btn-homelab {
      background: linear-gradient(135deg, #059669 0%, #047857 100%);
      color: white;
      box-shadow: 0 4px 14px rgba(5, 150, 105, 0.35);
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.06);
      color: #e2e8f0;
      border: 1px solid rgba(255, 255, 255, 0.1);
      padding: 12px 16px;
      font-size: 14px;
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.1);
    }
    .btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      transform: none !important;
    }

    .btn-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }

    .divider {
      height: 1px;
      background: rgba(255, 255, 255, 0.08);
      margin: 8px 0;
    }

    /* Auth modal or input */
    .pin-box {
      display: flex;
      gap: 8px;
      margin-top: 4px;
    }
    .pin-input {
      flex: 1;
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 10px 14px;
      font-family: var(--font-mono);
      font-size: 15px;
      color: white;
      letter-spacing: 2px;
    }
    .pin-input:focus {
      outline: none;
      border-color: var(--primary);
    }

    /* Logs & Toast */
    .log-box {
      font-family: var(--font-mono);
      font-size: 11px;
      color: #94a3b8;
      max-height: 120px;
      overflow-y: auto;
      background: rgba(0,0,0,0.35);
      border-radius: 10px;
      padding: 8px 12px;
      display: flex;
      flex-direction: column-reverse;
      gap: 4px;
    }
    .log-item { display: flex; gap: 6px; }
    .log-time { color: #64748b; }

    footer {
      text-align: center;
      font-size: 12px;
      color: #64748b;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="header-badge">
        <span>●</span> Cloudflare Edge Switcher
      </div>
      <h1>DR Control Center</h1>
      <p class="subtitle">Single Master Pointer Failover Orchestrator</p>
    </header>

    <!-- PIN Authentication Card -->
    <div class="card" id="authCard" style="display: none;">
      <div class="status-row" style="margin-bottom: 8px;">
        <span class="status-label">Kredensial Keamanan</span>
      </div>
      <div class="pin-box">
        <input type="password" id="pinInput" class="pin-input" placeholder="Masukkan PIN..." maxlength="12">
        <button class="btn btn-secondary" style="width: auto; padding: 10px 16px;" onclick="savePin()">Simpan</button>
      </div>
    </div>

    <!-- Live Status Card -->
    <div class="card">
      <div class="status-box">
        <div class="status-row">
          <span class="status-label">Status Routing Aktif</span>
          <div id="statusBadge" class="status-badge unknown">
            <span class="pulse-dot"></span>
            <span id="statusText">Checking...</span>
          </div>
        </div>

        <div class="record-info">
          <span>Master Record Pointer (Cloudflare CNAME)</span>
          <strong id="masterRecordText">${defaultMaster}</strong>
          <span style="margin-top: 6px;">Target Resolusi Saat Ini:</span>
          <code id="targetContentText" style="color: #67e8f9;">Loading...</code>
        </div>

        <div class="status-row" style="padding-top: 4px;">
          <span style="font-size: 11px; color: #64748b;">Cloudflare Proxy: <b style="color: #fb923c;">🟧 Proxied</b></span>
          <button onclick="fetchStatus()" style="background: none; border: none; color: #60a5fa; font-size: 12px; cursor: pointer; display: flex; align-items: center; gap: 4px;">
            ↻ Refresh
          </button>
        </div>
      </div>
    </div>

    <!-- Main Switcher Actions -->
    <div class="card">
      <div class="status-row" style="margin-bottom: 12px;">
        <span class="status-label">Alihkan Semua Traffic (DNS)</span>
      </div>
      <div class="actions-grid">
        <button id="btnSwitchTencent" class="btn btn-tencent" onclick="confirmSwitch('tencent')">
          🚀 Switch ke Tencent Standby
        </button>
        <button id="btnSwitchHomelab" class="btn btn-homelab" onclick="confirmSwitch('homelab')">
          🏠 Switch ke Homelab Primary
        </button>
      </div>

      <div class="divider"></div>

      <div class="status-row" style="margin-bottom: 10px; margin-top: 6px;">
        <span class="status-label">Kontrol Compute CVM (GitHub Actions)</span>
      </div>
      <div class="btn-row">
        <button id="btnStartCvm" class="btn btn-secondary" onclick="confirmCompute('start')">
          ⚡ Start CVM
        </button>
        <button id="btnStopCvm" class="btn btn-secondary" onclick="confirmCompute('stop')">
          🛑 Stop CVM ($0)
        </button>
      </div>
    </div>

    <!-- Activity Log Card -->
    <div class="card" style="padding: 14px 18px;">
      <div class="status-row" style="margin-bottom: 8px;">
        <span class="status-label">Log Aktivitas</span>
        <span id="lastUpdated" style="font-size: 11px; color: #64748b;">-</span>
      </div>
      <div id="logBox" class="log-box">
        <div class="log-item"><span class="log-time">[Init]</span> Siap mengontrol failover.</div>
      </div>
    </div>

    <footer>
      Zero-Cost Architecture • Cloudflare Edge • $0 Idle Compute
    </footer>
  </div>

  <script>
    let currentPin = localStorage.getItem("dr_admin_pin") || "";

    function log(msg) {
      const box = document.getElementById("logBox");
      const time = new Date().toLocaleTimeString();
      const div = document.createElement("div");
      div.className = "log-item";
      div.innerHTML = \`<span class="log-time">[\${time}]</span> \${msg}\`;
      box.prepend(div);
      document.getElementById("lastUpdated").innerText = time;
    }

    function checkAuth() {
      if (!currentPin) {
        document.getElementById("authCard").style.display = "block";
      } else {
        document.getElementById("authCard").style.display = "none";
      }
    }

    function savePin() {
      const val = document.getElementById("pinInput").value.trim();
      if (!val) return;
      currentPin = val;
      localStorage.setItem("dr_admin_pin", val);
      document.getElementById("authCard").style.display = "none";
      log("PIN berhasil disimpan.");
      fetchStatus();
    }

    async function fetchStatus() {
      checkAuth();
      try {
        const resp = await fetch("/api/status", {
          headers: { "X-Admin-Pin": currentPin }
        });
        if (resp.status === 401) {
          document.getElementById("authCard").style.display = "block";
          log("⚠️ PIN salah atau diperlukan.");
          return;
        }
        const data = await resp.json();
        if (data.error) {
          log("❌ Error: " + data.error);
          return;
        }

        const badge = document.getElementById("statusBadge");
        const statusText = document.getElementById("statusText");
        badge.className = "status-badge " + data.currentOrigin.toLowerCase();

        if (data.currentOrigin === "HOMELAB") {
          statusText.innerText = "HOMELAB PRIMARY";
        } else if (data.currentOrigin === "TENCENT") {
          statusText.innerText = "TENCENT STANDBY";
        } else {
          statusText.innerText = data.currentOrigin;
        }

        document.getElementById("masterRecordText").innerText = data.masterRecord;
        document.getElementById("targetContentText").innerText = data.targetContent;
        log("Status di-refresh: " + data.currentOrigin);
      } catch (err) {
        log("❌ Gagal menghubungi worker: " + err.message);
      }
    }

    async function confirmSwitch(target) {
      const label = target === "tencent" ? "TENCENT STANDBY" : "HOMELAB PRIMARY";
      if (!confirm(\`Yakin ingin mengalihkan SEMUA traffic ke \${label}?\\n\\nSemua subdomain akan otomatis diarahkan ke \${label} dalam 5-15 detik.\`)) {
        return;
      }

      setLoading(true);
      log(\`Memproses switch ke \${label}...\`);

      try {
        const resp = await fetch("/api/switch", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Admin-Pin": currentPin
          },
          body: JSON.stringify({ target })
        });
        const res = await resp.json();
        if (res.success) {
          log(\`✅ BERHASIL: Traffic sekarang menuju \${label}!\`);
          alert(\`SUKSES! Seluruh traffic telah dialihkan ke \${label}.\`);
        } else {
          log("❌ Gagal: " + (res.error || JSON.stringify(res)));
          alert("Gagal switch: " + (res.error || "Unknown error"));
        }
      } catch (err) {
        log("❌ Error koneksi: " + err.message);
      } finally {
        setLoading(false);
        fetchStatus();
      }
    }

    async function confirmCompute(action) {
      const label = action === "start" ? "MENYALAKAN (Start)" : "MEMATIKAN (Stop $0)";
      if (!confirm(\`Yakin ingin \${label} instance Tencent Cloud CVM via GitHub Actions?\`)) {
        return;
      }

      log(\`Dispatch GitHub Actions: \${action.toUpperCase()} CVM...\`);
      try {
        const resp = await fetch("/api/compute", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Admin-Pin": currentPin
          },
          body: JSON.stringify({ action })
        });
        const res = await resp.json();
        if (res.success) {
          log(\`✔ GitHub Action \${action.toUpperCase()} berhasil dipicu!\`);
          alert(\`Perintah \${action.toUpperCase()} CVM telah dikirim ke GitHub Actions runner.\`);
        } else {
          log("❌ Gagal compute: " + (res.error || JSON.stringify(res)));
        }
      } catch (err) {
        log("❌ Error: " + err.message);
      }
    }

    function setLoading(isLoading) {
      document.getElementById("btnSwitchTencent").disabled = isLoading;
      document.getElementById("btnSwitchHomelab").disabled = isLoading;
    }

    window.addEventListener("DOMContentLoaded", () => {
      checkAuth();
      fetchStatus();
    });
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}
