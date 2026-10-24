/**
 * Cloudflare Worker: Better Stack Failover Webhook Bridge
 * 
 * Flow:
 * 1. Better Stack detects outage -> sends webhook to this Worker
 * 2. Worker verifies secret & payload (incident.started vs incident.resolved)
 * 3. Worker calls GitHub API (repository_dispatch) on faisalaffan/infra-light
 * 4. GitHub Actions runs dr-failover.yml -> spins up / starts Standby instance (Warm boot / Terraform apply)
 */

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({ status: "ok", message: "Better Stack Failover Worker is online" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }

    try {
      // 1. Optional Bearer Token or Query Secret validation
      const authHeader = request.headers.get("Authorization");
      const url = new URL(request.url);
      const secretQuery = url.searchParams.get("secret");

      if (env.WEBHOOK_SECRET) {
        const expectedAuth = `Bearer ${env.WEBHOOK_SECRET}`;
        if (authHeader !== expectedAuth && secretQuery !== env.WEBHOOK_SECRET) {
          return new Response(JSON.stringify({ error: "Unauthorized: Invalid secret" }), {
            status: 401,
            headers: { "Content-Type": "application/json" }
          });
        }
      }

      const body = await request.json().catch(() => ({}));
      
      // Better Stack payload structure:
      // body.data.attributes.event -> "incident.started", "incident.resolved", "incident.acknowledged"
      // or legacy event formats
      const event = body.data?.attributes?.event || body.event || "incident.started";
      const incidentName = body.data?.attributes?.incident_title || body.data?.attributes?.name || "Homelab Outage";

      console.log(`[BetterStack Webhook] Event: ${event} | Incident: ${incidentName}`);

      let action = "auto";
      let eventType = "homelab-down";

      if (event === "incident.started") {
        action = "auto"; // Warm start CVM or Cold Terraform Apply
        eventType = "homelab-down";
      } else if (event === "incident.resolved") {
        // Optional: Can automatically shut down standby to save cost or keep it for manual review
        action = env.AUTO_STOP_ON_RESOLVE === "true" ? "stop" : "status";
        eventType = "homelab-recovered";
      }

      // 2. Trigger GitHub Actions repository_dispatch
      const GITHUB_REPO = env.GITHUB_REPO || "faisalaffan/infra-light";
      const GITHUB_PAT = env.GITHUB_PAT;

      if (!GITHUB_PAT) {
        return new Response(JSON.stringify({ error: "Configuration Error: GITHUB_PAT is missing" }), {
          status: 500,
          headers: { "Content-Type": "application/json" }
        });
      }

      const ghResponse = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/dispatches`, {
        method: "POST",
        headers: {
          "Accept": "application/vnd.github.v3+json",
          "Authorization": `token ${GITHUB_PAT}`,
          "User-Agent": "Cloudflare-Worker-BetterStack-DR"
        },
        body: JSON.stringify({
          event_type: eventType,
          client_payload: {
            source: "better-stack",
            event: event,
            incident: incidentName,
            action: action,
            provider: env.DEFAULT_PROVIDER || "tencent",
            environment: env.DEFAULT_ENV || "prod"
          }
        })
      });

      if (ghResponse.status === 204) {
        return new Response(JSON.stringify({
          status: "dispatched",
          event: event,
          action: action,
          target_repo: GITHUB_REPO,
          timestamp: new Date().toISOString()
        }), {
          status: 200,
          headers: { "Content-Type": "application/json" }
        });
      } else {
        const errText = await ghResponse.text();
        return new Response(JSON.stringify({
          error: "GitHub Dispatch failed",
          status_code: ghResponse.status,
          details: errText
        }), {
          status: 502,
          headers: { "Content-Type": "application/json" }
        });
      }

    } catch (err) {
      return new Response(JSON.stringify({ error: "Internal Error", message: err.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }
  }
};
