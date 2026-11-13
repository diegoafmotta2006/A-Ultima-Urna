#!/usr/bin/env python3
"""Ajusta o build web exportado do Godot para atualizar de verdade no navegador.

- Service worker: skipWaiting + clients.claim, network-first e recarga automatica
  quando havia cache antigo (evita ficar preso na versao velha do jogo).
- Atualiza o mtime de todos os arquivos (o export nao mexe no mtime nesta pasta,
  e o navegador recebia 304 com o If-Modified-Since antigo).

Uso: python3 tools/patch_web_sw.py [build/web]
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

MARKER = "// REA: network-first SW"

INSTALL_OLD = """self.addEventListener('install', (event) => {
\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));
});"""
INSTALL_NEW = """// REA: network-first SW
self.addEventListener('install', (event) => {
\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)).then(() => self.skipWaiting()));
});"""

ACTIVATE_OLD = """self.addEventListener('activate', (event) => {
\tevent.waitUntil(caches.keys().then(
\t\tfunction (keys) {
\t\t\t// Remove old caches.
\t\t\treturn Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));
\t\t}
\t).then(function () {
\t\t// Enable navigation preload if available.
\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
\t}));
});"""
ACTIVATE_NEW = """self.addEventListener('activate', (event) => {
\tevent.waitUntil((async () => {
\t\tconst keys = await caches.keys();
\t\tconst hadOldCache = keys.some((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME);
\t\tawait Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));
\t\tif ('navigationPreload' in self.registration) {
\t\t\tawait self.registration.navigationPreload.enable();
\t\t}
\t\tawait self.clients.claim();
\t\tif (hadOldCache) {
\t\t\tconst clients = await self.clients.matchAll({ type: 'window' });
\t\t\tclients.forEach((client) => client.navigate(client.url));
\t\t}
\t})());
});"""

FETCH_START = "\t\t\tevent.respondWith((async () => {\n\t\t\t\t// Try to use cache first"
FETCH_END = "\t\t\t})());"
FETCH_NEW = """\t\t\tevent.respondWith((async () => {
\t\t\t\tconst cache = await caches.open(CACHE_NAME);
\t\t\t\t// Network first para receber novas builds; cache apenas como fallback offline.
\t\t\t\ttry {
\t\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\t\tif (response != null) {
\t\t\t\t\t\treturn response;
\t\t\t\t\t}
\t\t\t\t} catch (e) {
\t\t\t\t\tconst cached = await cache.match(event.request);
\t\t\t\t\tif (cached != null) {
\t\t\t\t\t\treturn cached;
\t\t\t\t\t}
\t\t\t\t\tif (isNavigate) {
\t\t\t\t\t\treturn caches.match(OFFLINE_URL);
\t\t\t\t\t}
\t\t\t\t\tthrow e;
\t\t\t\t}
\t\t\t\tconst cached = await cache.match(event.request);
\t\t\t\tif (cached != null) {
\t\t\t\t\treturn cached;
\t\t\t\t}
\t\t\t\treturn caches.match(OFFLINE_URL);
\t\t\t})());"""


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    sw = root / "index.service.worker.js"
    if not sw.is_file():
        print(f"erro: {sw} nao encontrado", file=sys.stderr)
        return 1

    s = sw.read_text()
    if MARKER not in s:
        if INSTALL_OLD not in s or ACTIVATE_OLD not in s:
            print("erro: template do service worker inesperado", file=sys.stderr)
            return 1
        s = s.replace(INSTALL_OLD, INSTALL_NEW)
        s = s.replace(ACTIVATE_OLD, ACTIVATE_NEW)
        start = s.find(FETCH_START)
        if start < 0:
            print("erro: bloco fetch do service worker nao encontrado", file=sys.stderr)
            return 1
        end = s.find(FETCH_END, start)
        if end < 0:
            print("erro: fim do bloco fetch nao encontrado", file=sys.stderr)
            return 1
        end += len(FETCH_END)
        s = s[:start] + FETCH_NEW + s[end:]
        sw.write_text(s)
        print("service worker ajustado")
    else:
        print("service worker ja estava ajustado")

    for path in root.rglob("*"):
        if path.is_file():
            os.utime(path, None)
    print("mtimes atualizados")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
