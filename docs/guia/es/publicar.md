# Compilar y publicar

Publica tu app como un sitio estático, con el HTML ya renderizado, o como un servidor de Dart que renderiza cada petición.

:::flutter Flutter: `flutter build web` · Thor: `thor export` o `thor build`

## Elige

Las rutas, los widgets y los estilos son los mismos en los dos modos; cambia cuándo corre `load`.

```bash
thor export --base-url https://my-site.com   # static site → build/site
thor build                                   # server      → build/server
```

| Criterio | Sitio estático | Servidor |
|---|---|---|
| Para | documentación, landings, blogs y portafolios | apps con sesión, datos que cambian con frecuencia y formularios que guardan datos |
| Cuándo corre `load` | una vez, al exportar | en cada petición (o según `cache`) |
| Acciones de formulario | no | sí |
| Dónde se publica | cualquier hosting de archivos | cualquier lugar que ejecute un binario o un contenedor |

Empieza con una [tabla de rutas](navegacion.md): sirve para los dos modos, y pasar de estático a servidor no obliga a reescribir páginas.

## Sitio estático

`thor export` pide cada ruta al mismo handler que usaría el servidor y escribe el resultado en `build/site`. El archivo `bin/export.dart` dice qué rutas hay:

```dart no-check
// bin/export.dart
import 'dart:io';

import 'package:my_site/handler.dart';
import 'package:thor_server/thor_server.dart';

Future<void> main(List<String> args) async {
  final report = await exportSite(
    siteHandler(), // the server's same RouteHandler
    paths: ['/', '/pricing', for (final p in posts) '/blog/${p.slug}'],
    outDir: 'build/site',
    baseUrl: args.length > 1 ? args[1] : null, // https://my-site.com
    notFoundPath: '/__missing__',
    staticDir: 'web',
  );
  exit(report.ok ? 0 : 1);
}
```

```bash
thor export --base-url https://my-site.com
thor preview   # serves build/site like a hosting would
```

Al exportar:

- cada ruta es un archivo (`/` → `index.html`, `/pricing` → `pricing.html`) y `notFoundPath` da el `404.html` que los hostings muestran para lo que no existe;
- con `--base-url` salen además `sitemap.xml` y `robots.txt`;
- la exportación falla, y lista cada problema, si una página no responde `200` o si un enlace interno no lleva a una página exportada, a un archivo de `web/` o a un `#ancla` existente.

Un sitio exportado conserva todo lo nativo (diálogos, menús, acordeones, tema oscuro) y los ViewModels de sus páginas. Sube `build/site` a cualquier hosting estático: Netlify, Cloudflare Pages, GitHub Pages, Firebase Hosting, Vercel, S3 o nginx.

> **Importante:** `load` corre una sola vez, al exportar: un dato que cambia después no aparece hasta que exportas y publicas otra vez.

### Una sola página

Una app sin rutas es una sola página y no necesita `bin/export.dart`:

```dart
// lib/main.server.dart
void main() {
  initializeThor(styles: const []);
  runApp(const Document(title: 'Counter', body: ThorApp(child: Counter())));
}
```

`thor build` la renderiza en `build/site` y muestra lo que pesa (`7.5 KB html, 0.0 KB js (gzip)`).

## Servidor

Para una app con `bin/server.dart`, `thor build` compila un ejecutable nativo: en producción no hace falta el SDK de Dart.

```bash
thor build               # → build/server, build/public and build/run.sh
thor preview             # runs it at http://localhost:4400
PORT=8080 build/server   # in production
```

Lo que se publica es `build/server` junto con `build/public` y `build/images.json`, más `build/resources` si un pubspec declara `thor: resources:` o `thor: sdk:` ([CLI](cli.md#thor-build); el `Dockerfile` de `thor deploy init` la copia). Las variables que declara `lib/env.dart` se configuran en el hosting; si falta alguna, el servidor no arranca y la nombra ([Sesión y seguridad](sesion-y-seguridad.md#entorno-y-secretos)).

| Variable | Qué hace |
|---|---|
| `PORT` | el puerto; la plantilla de `thor create` lo lee de ahí, como esperan Fly, Railway y Render |
| `SECURE_COOKIES` | `true` fuerza `Secure` en las cookies y `false` lo quita; sin definir, sigue a la petición (HTTPS o `X-Forwarded-Proto`) |
| `ISOLATES` | cuántos isolates; por omisión uno por núcleo, hasta 4 |
| `DART_VM_OPTIONS` | opciones de la VM; `build/run.sh` y el `Dockerfile` traen las que hacen falta con más de 4 isolates |

- **Salud:** `GET /_thor/health` responde `200 {"status":"ok"}` mientras el servidor atiende y `503` al apagarse. `ThorServer(healthPath: null)` lo desactiva.
- **Apagado limpio:** con `SIGTERM` o Ctrl-C, el servidor deja de aceptar conexiones, termina las peticiones en curso (hasta `shutdownTimeout`, 8 s) y sale.
- **Compresión:** el servidor comprime con gzip el HTML y los archivos de texto. Para Brotli, pon delante un CDN o un proxy que lo haga (Caddy, nginx, Cloudflare).
- **Caché de páginas:** una página con `cache:` comparte su HTML entre peticiones sin sesión ([Servidor y acciones](red-y-servidor.md#caché-y-metadatos)).
- **Detrás de un CDN:** un `LazyPiece` pide su parte en la misma ruta con `?thor-piece=<id>`. Configura el CDN para que incluya `thor-piece` en su clave de caché.

## `thor deploy init`

`thor deploy init` escribe en tu proyecto la configuración que pide cada hosting y no publica nada: revisas los archivos, los subes con tu repositorio y publicas con la herramienta del hosting. No reemplaza un archivo existente (`--force` lo hace) e imprime los comandos siguientes con las variables de `lib/env.dart` que debes configurar.

```bash
thor deploy init fly          # in the app's folder
thor deploy init docker shop  # or naming the app
```

Una app con servidor se publica como contenedor: `docker`, `fly`, `railway` y `render` usan la misma imagen. El `Dockerfile` tiene dos etapas, la primera compila con `thor build` en Linux y la final contiene solo el ejecutable, `build/public`, el manifiesto de imágenes y `deploy/healthcheck.dart`, con un usuario sin privilegios.

:::tabs
@tab Docker
```bash
thor deploy init docker
docker build -f Dockerfile -t shop .   # in a monorepo: -f services/shop/Dockerfile, from the root
docker run -p 8080:8080 -e API_URL=https://… shop
```
Docker marca el contenedor como `healthy` cuando `/_thor/health` responde, y `docker stop` espera a que terminen las peticiones en curso.
@tab Fly.io
```bash
thor deploy init fly
fly secrets set SESSION_SECRET=…   # the secrets of your lib/env.dart
fly deploy
```
`fly.toml` expone el puerto 8080 con HTTPS forzado, comprueba `/_thor/health`, apaga las máquinas sin tráfico y da 10 s para el apagado limpio.
@tab Railway
```bash
thor deploy init railway
```
Crea un servicio desde el repositorio. `railway.json` indica el `Dockerfile` y el health check; Railway define `PORT`. En un monorepo, indica la ruta de `railway.json` en la configuración del servicio.
@tab Render
```bash
thor deploy init render
```
`render.yaml` es un Blueprint (New → Blueprint en Render): un servicio web con Docker, el health check y tus variables listadas. Render lo lee en la raíz del repositorio.
:::

Un sitio estático se publica como archivos: `cloudflare-pages`, `vercel` y `netlify` publican `build/site`. Los tres reciben `deploy/build.sh` (corre `thor build`, o `thor export` si hay `bin/export.dart`, y pide `SITE_URL` para el sitemap) y las reglas de caché de ese hosting. Sus entornos de compilación no traen Dart: compila en tu máquina o en CI y sube la carpeta.

:::tabs
@tab Cloudflare Pages
```bash
thor deploy init cloudflare-pages
sh deploy/build.sh
npx wrangler pages deploy
```
@tab Vercel
```bash
thor deploy init vercel
sh deploy/build.sh   # copies deploy/vercel.json to build/site
vercel deploy build/site --prod
```
@tab Netlify
```bash
thor deploy init netlify
sh deploy/build.sh
netlify deploy --prod --dir build/site
```
:::

Los hostings de funciones de JavaScript (Cloudflare Workers, Vercel Functions, Netlify Functions, AWS Lambda) no ejecutan un servidor de Dart: `thor deploy init` lo indica ([THOR-B017](../../errores/THOR-B017.md)) y sugiere un contenedor o un sitio estático.

## Caché del navegador

`thor build` y `thor export` renombran cada archivo que pide una página (el script de los ViewModels, imágenes, fuentes) con un hash de su contenido. Así una página siempre carga los archivos con los que se compiló, y una página abierta cuyos archivos ya no existen se recarga sola una vez. No se renombran los archivos que otros piden por su nombre: `favicon*`, `apple-touch-icon*`, `og*`, `robots.txt`, `manifest` y `sitemap`.

Para que una publicación se vea de inmediato, el hosting debe revalidar el HTML y guardar para siempre lo que tiene hash:

:::tabs
@tab Netlify / Cloudflare
El build escribe `build/site/_headers` con estas reglas, `/_thor/*` incluido, y conserva las tuyas.
@tab Firebase
```jsonc
// firebase.json
"headers": [
  { "source": "**/*.html", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] },
  { "source": "/_thor/**", "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] },
  { "regex": ".*\\.[0-9a-f]{8}\\.[a-z0-9]+$",
    "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] }
]
```
@tab Vercel
```jsonc
// vercel.json
{ "headers": [
  { "source": "/(.*).html", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] },
  { "source": "/_thor/(.*)", "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] },
  { "source": "/(.*)\\.([0-9a-f]{8})\\.(js|png|jpg|webp|avif|woff2|svg|css)",
    "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] } ] }
```
@tab nginx
```nginx
location ~* \.[0-9a-f]{8}\.[a-z0-9]+$ { add_header Cache-Control "public, max-age=31536000, immutable"; }
location /_thor/                        { add_header Cache-Control "public, max-age=31536000, immutable"; }
location ~* \.html$                     { add_header Cache-Control "no-cache"; }
```
@tab S3 + CloudFront
Sube los archivos con hash con `--cache-control "public, max-age=31536000, immutable"` y los `.html` con `--cache-control "no-cache"`.
:::

El servidor de Thor ya responde así a los archivos de `web/`: `immutable` para los nombres con hash y `ETag` para el resto.

## Estilos compartidos

Por omisión, cada página lleva sus estilos en línea. En un sitio donde el usuario visita muchas páginas, `share_styles` mueve los estilos que comparten a una hoja que el navegador guarda en caché ([Estilos avanzados](estilos-avanzados.md#hojas-de-estilo-por-nivel)). La primera visita paga una petición más antes de mostrar la página, por eso está desactivado.

```yaml
# pubspec.yaml
thor:
  share_styles: true
```

## Antes de publicar

- [ ] `thor doctor` no reporta problemas y `thor test` pasa ([Pruebas](pruebas.md)).
- [ ] `thor preview` muestra el sitio o el servidor como en producción.
- [ ] Cada página tiene título y descripción propios ([SEO](seo.md)).
- [ ] Las páginas funcionan con JavaScript desactivado.
- [ ] Las reglas de caché del hosting están configuradas.
- [ ] Con servidor: `/_thor/health` responde `200` y las variables de `lib/env.dart` están en el hosting.

## Siguientes pasos

:::cards
- [SEO](seo.md) — título, vista previa y sitemap de cada página
- [Sesión y seguridad](sesion-y-seguridad.md) — entorno, secretos y Content-Security-Policy
- [El comando thor](cli.md#thor-export) — `thor export` y `thor build` con sus opciones
:::
