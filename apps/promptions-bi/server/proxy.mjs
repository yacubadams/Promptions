#!/usr/bin/env node
import http from "http";
import https from "https";

const PORT = process.env.PROXY_PORT ?? 3006;
const API_KEY = process.env.ANTHROPIC_API_KEY;

if (!API_KEY) { console.error("❌  ANTHROPIC_API_KEY required."); process.exit(1); }

const server = http.createServer((req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }
    if (req.method !== "POST" || !req.url?.startsWith("/v1/")) { res.writeHead(404); res.end("Not found"); return; }
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
        const body = Buffer.concat(chunks);
        const proxyReq = https.request({
            hostname: "api.anthropic.com", path: req.url, method: "POST",
            headers: { "Content-Type": "application/json", "Content-Length": body.length, "x-api-key": API_KEY, "anthropic-version": "2023-06-01" },
        }, (proxyRes) => { res.writeHead(proxyRes.statusCode, proxyRes.headers); proxyRes.pipe(res); });
        proxyReq.on("error", (e) => { console.error("Proxy error:", e); res.writeHead(502); res.end("Bad gateway"); });
        proxyReq.write(body); proxyReq.end();
    });
});

server.listen(PORT, () => console.log(`✅  BI Proxy on http://localhost:${PORT}`));
