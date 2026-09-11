#!/usr/bin/env node
/**
 * relay.js
 *
 * TCP NDJSON -> WebSocket broadcast relay
 *
 * mGBA Lua script connects here over TCP (default 8765)
 * Browser overlays connect here over WebSocket (default 8080)
 *
 * No dependencies required beyond ws.
 */

const net = require("net");
const http = require("http");
const WebSocket = require("ws");

const TCP_PORT = Number(process.env.TCP_PORT || 8765);
const WS_PORT = Number(process.env.WS_PORT || 8080);
const WS_HOST = process.env.WS_HOST || "127.0.0.1";

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Emerald overlay relay is running.\n");
});

const wss = new WebSocket.Server({ server });

// Last party message seen. The Lua script only sends party_init once, so browsers
// that connect (or refresh) later would otherwise wait until the party changes.
let lastParty = null;

function broadcast(raw) {
  for (const client of wss.clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(raw);
    }
  }
}

wss.on("connection", (ws, req) => {
  console.log(`[ws] client connected from ${req.socket.remoteAddress}`);
  if (lastParty) ws.send(lastParty);
  ws.on("close", () => {
    console.log("[ws] client disconnected");
  });
});

server.listen(WS_PORT, WS_HOST, () => {
  console.log(`[ws] listening on ws://${WS_HOST}:${WS_PORT}`);
});

const tcpServer = net.createServer((socket) => {
  const remote = `${socket.remoteAddress}:${socket.remotePort}`;
  console.log(`[tcp] client connected from ${remote}`);

  let buffer = "";

  socket.setEncoding("utf8");

  socket.on("data", (chunk) => {
    buffer += chunk;

    let newlineIndex;
    while ((newlineIndex = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, newlineIndex).trim();
      buffer = buffer.slice(newlineIndex + 1);

      if (!line) continue;

      try {
        const msg = JSON.parse(line);
        if (msg.type === "party_init" || msg.type === "party_changed") lastParty = line;
        broadcast(line);
      } catch (err) {
        console.warn("[tcp] dropped invalid JSON line:", err.message);
      }
    }
  });

  socket.on("close", () => {
    console.log(`[tcp] client disconnected from ${remote}`);
  });

  socket.on("error", (err) => {
    console.error(`[tcp] socket error from ${remote}:`, err.message);
  });
});

tcpServer.listen(TCP_PORT, "127.0.0.1", () => {
  console.log(`[tcp] listening on 127.0.0.1:${TCP_PORT}`);
});
