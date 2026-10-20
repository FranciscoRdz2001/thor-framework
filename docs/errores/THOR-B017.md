# THOR-B017 · Un destino de deploy que no aplica a esta app

**Dónde:** `thor_cli` · `thor deploy init <destino>`.

## Qué pasó

El destino no puede servir esta app, o no se puede armar su imagen:

- un destino de servidor (`docker`, `fly`, `railway`, `render`) para un sitio estático (sin `bin/server.dart`);
- un hosting de archivos (`cloudflare-pages`, `vercel`, `netlify`) para una app con servidor que no se exporta (sin `bin/export.dart`);
- un hosting de funciones de JavaScript (`cloudflare-workers`, `vercel-functions`, `netlify-functions`, `lambda`): no corren un servidor de Dart;
- `thor_ui` viene de una carpeta (`path:`) fuera de lo que ve la imagen de Docker.

## Por qué

Una app de thor con servidor es un ejecutable nativo que escucha en un puerto: necesita un contenedor. Un sitio estático son archivos: necesita un hosting de archivos con las cachés correctas. La imagen de Docker se construye con lo que hay dentro del contexto de build: una dependencia fuera de él no existe ahí.

## Cómo se arregla

```bash
# WRONG: un servidor de Dart en funciones de JavaScript
thor deploy init cloudflare-workers
```

```bash
# RIGHT: el servidor en un contenedor…
thor deploy init fly
# …o el sitio exportado en un hosting de archivos (con bin/export.dart)
thor deploy init cloudflare-pages
```

Si `thor_ui` viene de una carpeta fuera del proyecto, toma thor de git (`thor create --git <url>`) o construye desde una carpeta que contenga las dos.

[Todos los códigos](README.md)
