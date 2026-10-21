# Sesión y seguridad

Protege tu app: cookie de sesión firmada, origen de los formularios, secretos en el entorno, límite de intentos y encabezados de seguridad.

Thor cubre una parte por omisión; el resto lo declaras tú:

| Tema | Lo que hace Thor | Lo que escribes |
|---|---|---|
| CSRF | acepta un `POST` solo si su `Origin` es el del sitio | `trustedOrigins` si otro sitio tuyo envía formularios |
| HTML | todo texto es texto, nunca se interpreta como HTML | no insertar HTML de un usuario ([Paquetes de pub](paquetes.md#markdown)) |
| Acciones, queries y commands | corren después del middleware y los guards de la página | autorizar lo que leen o escriben |
| Argumentos del navegador | llegan con su tipo o responden `400` | comprobar que el usuario puede modificar ese `id` |
| Secretos | un `Secret` no se imprime ni se serializa | no ponerlos en una página ni en un ViewModel |
| Archivos estáticos | no sirve archivos ocultos ni `.map` en producción | no poner secretos en `web/` |

## Encabezados de seguridad

`securityHeaders` agrega a cada respuesta del grupo `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, `Cross-Origin-Opener-Policy` y un `Permissions-Policy` que desactiva cámara, micrófono y ubicación. Con `hsts`, el navegador usa solo HTTPS durante ese tiempo.

```dart
Group(
  middleware: [securityHeaders(hsts: const Duration(days: 365))],
  children: [homeRoute, accountRoute],
)
```

Para que también lleguen a los archivos estáticos, al health check y a los errores globales, pásalos al servidor:

```dart
ThorServer(
  handler: handler,
  publicDir: ThorServer.appPublicDir(),
  securityHeaders: const SecurityHeaders(hsts: Duration(days: 365)),
)
```

Un encabezado que la respuesta ya trae no se reemplaza.

## Content-Security-Policy

`contentSecurityPolicy` pone una política tipada y un nonce nuevo en cada petición. Cada `<script>` y `<style>` que Thor emite (también los tuyos con `html.script` y los de las partes que llegan después) lleva ese nonce, así que la política no necesita `'unsafe-inline'`.

```dart
Group(
  middleware: [
    contentSecurityPolicy(
      ContentSecurityPolicy(
        imgSrc: [CspSource.self, CspSource.data, CspSource.host('https://cdn.example.com')],
        reportOnly: true, // reports without blocking; remove it when there are no reports
        reportUri: Uri.parse('/csp-report'),
      ),
    ),
  ],
  children: [homeRoute],
)
```

- Un `<script>` que llega como texto (un `RawText`, un renderizador de markdown) no recibe nonce y la política lo bloquea.
- Los atributos `style` que Thor escribe están permitidos por `style-src-attr 'unsafe-inline'`, que nunca permite elementos `<style>`.
- Los atributos de evento (`oninput`, `onclick`…) no admiten nonce. Para conservarlos: `scriptSrcAttr: [CspSource.unsafeHashes, ...CspSource.thorHandlers]`.
- En una respuesta escrita a mano, `request.cspNonce` es el nonce.
- Una página con nonce sale sin `ETag` y con `Cache-Control: private`: no la pongas detrás de una caché compartida.
- La política cubre las páginas del grupo, no los archivos estáticos ni los errores globales.

Un sitio estático no tiene servidor que ponga un nonce. Cada código en línea de Thor es constante y se permite con su hash en `script-src`; los atributos de evento piden además `'unsafe-hashes'`. Sin su hash, cada uno se degrada sin romper la página:

| Función | Qué hace | Sin él |
|---|---|---|
| `TextField(maxLength:)` | `oninput`: actualiza el contador | el contador queda con la cuenta inicial |
| `Image(errorBuilder:)` | `onerror`: muestra el respaldo | no aparece el respaldo |
| `Image(loadingBuilder:)` | `onload`: quita el marcador de carga | el marcador de carga se queda |
| `Popover`, `MenuAnchor` con `closeOnNavigate` | `onclick`: cierra al navegar | no se cierran al navegar |
| `Drawer` con `closeOnNavigate` | `onclick`: cierra al navegar | no se cierra al navegar |
| `FutureBuilder` con `defer` | coloca los datos que llegan después | los datos llegan, pero quedan los esqueletos |
| `LazyPiece` | pide la parte bajo demanda | la parte no se pide |
| `ExpansionTile(permanentFrom:)` | quita el encabezado del orden de Tab desde el punto de quiebre | el encabezado sigue recibiendo el foco con Tab |
| `Form` | estado de envío, foco del primer error, posición conservada | el formulario envía sin esas tres cosas |
| `LinearProgressIndicator.upload()` | muestra el progreso de la subida | no hay barra; el formulario envía igual |
| `Form(stay: true)`, `FileField(submitOnChange: true)` | envía el formulario sin cambiar de página, o al elegir archivos | el formulario envía de la forma normal y la página siguiente muestra el aviso |
| `darkTheme` | recuerda el tema claro u oscuro elegido | la elección no se recuerda entre páginas |
| Precarga de enlaces en Firefox y Safari | carga la precarga de respaldo | esos navegadores no precargan |
| `PageTransition.slide` | invierte la dirección al volver atrás | la transición siempre avanza |

Los hashes, en el mismo orden que la tabla, para la cabecera `Content-Security-Policy` del hosting:

```text
script-src 'self' 'unsafe-hashes'
  'sha256-d1k8y4HZiUcsRf7/fSwzLY3eloLLZikspOpQ2YrXhHs='
  'sha256-yMxl8xCTUafbfCLCfCzjwjSLtzTIs2YxOZEF/a/1y/M='
  'sha256-8bvL4iOwjjseCopvPb3HpKMRh3VhhhOLSaXO6KWVG7c='
  'sha256-L/gjp/lXf1b++Z++rgw+P1gwp3nzVwoiQxErAc/1Brc='
  'sha256-RyS7b/uVe1C+1Gd8n4HR1kH+n+01SmpZRn+mOR9CJUk='
  'sha256-Mxg6UhxGzKjB5ugabTWXccqT/DAbMskkZQEV7uRLGC0='
  'sha256-omYRSsAIVTFaZQZ5jkLRqAjKxDmfv/hmDNkTg3ETp8I='
  'sha256-tiaf4Ty5SJfKEBWPKh/B6ZKlL80Xn7N9K+Q1zZFqvy4='
  'sha256-zlm6MXXoeDrl6SMrFRQc7NRm+ZLmsHjlpTuOW4kCA9g='
  'sha256-Asckod0Qy5jICUwq+JiuJxRdh6mNnBMYtL2+X0M9imE='
  'sha256-iXlGGEvhMoI+078S7Itq+JPK7xMdbE8uvolspVmGsuc='
  'sha256-aDxpB7mloHYVrqMV+HWFEAdeclRvWIRgIUucid0L9GI='
  'sha256-+vjJOlGdlPgTbJrnHZFLodugWUckeEMjYbDKn3UzboI='
  'sha256-B07+DJJ+zTmWcS+ikeNI2qf05ksFMdwClL0hweHfXo8='
```

`ThorApp(engineLoading: EngineLoading.eager)` carga el script de los ViewModels sin código en línea. La precarga de enlaces (`PageNavigation`) pone un `<script type="speculationrules">` en cada página; con servidor, `PageNavigation(delivery: SpeculationDelivery.header)` envía las reglas en una cabecera, y `ThorPage(prefetch: false)` excluye una página cuyo `GET` es costoso.

### Analítica y gestores de etiquetas

Un fragmento que debe correr en el `<head>` (Google Tag Manager, Clarity, una configuración de gtag) va en `WidgetRenderer(head:)` como `html.script`. Tanto el cargador (`src:`) como el código en línea (`content:`) reciben el nonce de la petición, y la política solo necesita los hosts de los que carga o a los que reporta el fragmento.

```dart no-check
WidgetRenderer(
  head: [
    html.script(src: 'https://www.googletagmanager.com/gtag/js?id=G-XXXX', async: true),
    html.script(content: "window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}gtag('js',new Date());gtag('config','G-XXXX');"),
  ],
  ...
)

contentSecurityPolicy(
  ContentSecurityPolicy(
    scriptSrc: [CspSource.host('https://www.googletagmanager.com')],
    connectSrc: [CspSource.host('https://www.google-analytics.com')],
  ),
)
```

Un fragmento que inyecta más scripts desde el primero (Tag Manager lo hace) necesita `CspSource.strictDynamic` en `scriptSrc`.

## Host y origen público

En producción, declara a qué dominios responde el servidor. Cualquier otro `Host` responde `400` antes de llegar a una página, así que un `Host` falso no entra en enlaces, caché ni correos.

```dart
ThorServer(
  handler: handler,
  allowedHosts: ['example.com', '*.example.com'], // `*.` = subdomains
  publicOrigin: Uri.parse('https://example.com'),
)
```

Con `publicOrigin`, la app ve siempre ese origen: lo usan `og:url`, los canonicals, el sitemap, las redirecciones, la comprobación de `Origin` de los formularios y las claves de caché, y las cookies salen con `Secure`. Implica un único origen público: en una app con varios subdominios usa solo `allowedHosts`.

Detrás de un proxy solo se comprueba `Host`; `X-Forwarded-Host` se ignora. Si tu proxy reescribe `Host` a un nombre interno, configúralo para que conserve el público (nginx: `proxy_set_header Host $host;`) o declara `publicOrigin`. `thor dev` ignora ambos ajustes, y el health check responde a cualquier host.

## Cookie firmada

`SignedCookies` firma un valor con HMAC-SHA256: el navegador lo lee pero no puede cambiarlo. La firma incluye la hora, y el servidor comprueba `maxAge`: una cookie robada deja de servir al vencer, aunque el navegador la conserve.

```dart
final session = SignedCookies(
  env.secret, // 32 bytes or more, outside the repo
  purpose: 'session',
  maxAge: const Duration(days: 30),
);

request.response.setCookie('session', session.sign(jsonEncode(account)),
    maxAge: const Duration(days: 30));
final user = session.verify(request.cookies['session']); // null if it expired
```

| Parámetro | Qué hace |
|---|---|
| `purpose` | para qué es el valor; una cookie firmada con otro propósito no verifica |
| `maxAge` | edad máxima del valor; `null` no vence (no lo uses en sesiones) |
| `previousSecrets` | claves anteriores a una rotación: solo verifican, nunca firman |
| `clock` | el reloj de las pruebas |

Si un secreto firma más de una cookie, dale a cada una su `purpose`: sin él, un valor firmado para un aviso se aceptaría como sesión. Con `purpose: 'session'` y sin `maxAge`, `thor dev` avisa ([THOR-P033](../../errores/THOR-P033.md)).

### Rotar la clave

Firma con la clave nueva y verifica con todas: nadie pierde la sesión al rotar, y cada cookie conserva su vencimiento.

```dart
final session = SignedCookies(
  newSecret,
  previousSecrets: [oldSecret], // remove it when its cookies expire
  maxAge: const Duration(days: 30),
);
```

## Inicio de sesión

Tras iniciar sesión, la app devuelve al usuario a la página que pedía. Esa dirección llega del navegador y hay que validarla.

### Volver a donde iba

`safeNext` devuelve el destino solo si es una ruta de este sitio; si no, `fallback`. Un `?next=https://other.site` sin validar es una redirección abierta: úsalo siempre antes de redirigir a una dirección que envió el navegador.

```dart
Future<ActionResult?> signIn(PageRequest request) async {
  final form = await request.form();
  // ... check the password ...
  return Redirect(safeNext(request, form['next'], fallback: const RouteUrl('/account')));
}
```

| Entrada | Resultado |
|---|---|
| `/cart?a=1#top` | tal cual |
| `https://your.site/cart` (mismo origen) | `/cart` |
| `https://other.site/x`, `//other.site`, `/\other.site`, `javascript:…` | `fallback` |
| `/%2F/other.site`, doble codificación, saltos de línea | `fallback` |

### Redirigir al inicio de sesión

Un repositorio lanza `HttpError(401)` cuando el backend no reconoce la sesión ([Capa de datos](capa-datos.md#errores-del-backend-a-la-página)). `signInOn401` en el middleware del grupo convierte ese 401 en una redirección al inicio de sesión, con la página pedida en `?next=`.

```dart
Group(
  middleware: [session, signInOn401('/login')],
  children: [ordersRoute],
)
// A load that throws HttpError(StatusCode.unauthorized) ends at /login?next=%2Forders
```

Una query o un command que reciben el 401 responden JSON con `redirect`. Los demás estados (403, 404…) no cambian.

## Límite de intentos

`RateLimit` cuenta intentos por clave dentro de una ventana fija. Como middleware de un grupo, al pasar el límite responde `429` con `Retry-After`: una página de error, o JSON (`{error, retryAfter}`) para una query o un command.

```dart
final loginLimit = RateLimit(max: 10, window: const Duration(minutes: 15));

Group(middleware: loginLimit.middleware(), children: [loginRoute]);
```

Dentro de una acción, para mostrar el formulario con un mensaje y limitar también por cuenta:

```dart
final limited = await loginLimit.limit(
  request,
  key: 'login:${email.toLowerCase()}',
  data: {'error': 'Too many attempts. Try again in a few minutes.'},
);
if (limited != null) return limited; // 429 + Retry-After
```

| Parámetro | Qué hace |
|---|---|
| `max`, `window` | intentos por clave y duración de la ventana |
| `key` | la clave de una petición (por omisión `RateLimit.clientIp`); `null` no limita |
| `trustedProxies` | cuántos proxies delante del servidor agregan a `X-Forwarded-For` (0 por omisión) |
| `store` | dónde viven los contadores (`RateLimitStore`) |
| `reset(key)` | olvida una clave tras un inicio de sesión correcto; úsalo con la clave de la cuenta, nunca con la de la IP |

`X-Forwarded-For` lo escribe el cliente: por omisión se ignora y la clave es la dirección de la conexión. Detrás de un proxy, indica cuántos hay con `trustedProxies: 1`; sin un proxy que reescriba el encabezado, no lo actives.

> **Importante:** El almacén por omisión vive en memoria de cada isolate. Con varios isolates o varias instancias, cada uno cuenta aparte. Para un límite estricto, implementa `RateLimitStore` sobre un almacén compartido (Redis `INCR` y `EXPIRE`) con un `increment` atómico.

## Entorno y secretos

Las variables de entorno de la app (la URL de la API, el secreto de la sesión, el puerto) se declaran una vez, con su tipo, en `lib/env.dart`. El servidor las comprueba al arrancar y, si falta alguna, no arranca y las lista todas ([THOR-P011](../../errores/THOR-P011.md)).

```dart
// lib/env.dart
import 'package:thor_server/thor_server.dart';

abstract final class AppEnv {
  static const api = EnvUrl('API_URL', fallback: 'https://api.example.com');
  static const port = EnvInt('PORT', fallback: 4300);
  static const title = EnvString('SITE_TITLE', public: true);
  static const session = EnvSecret('SESSION_SECRET', minLength: 32);
  static const isolates = EnvOptional(EnvInt('ISOLATES'));
  static const schema = EnvSchema([api, port, title, session, isolates]);
}
```

```dart
// bin/server.dart: first of all
final env = AppEnv.schema.load();
final api = env.of(AppEnv.api); // a Uri
```

`thor create` genera `lib/env.dart` y agrega `.env` al `.gitignore`. `load()` solo lee lo que está en `EnvSchema([...])`; el editor marca una variable declarada que falta en la lista (`env_var_not_in_schema`).

| Tipo | Lee | Ejemplo |
|---|---|---|
| `EnvString` | un texto | `SITE_TITLE=My shop` |
| `EnvInt` | un entero | `PORT=4300` |
| `EnvBool` | `true`/`false`, `1`/`0`, `yes`/`no` | `SECURE_COOKIES=true` |
| `EnvUrl` | una URL `http` o `https` con host, como `Uri` | `API_URL=https://api.example.com` |
| `EnvSecret` | un secreto, sin valor por omisión y con largo mínimo | `SESSION_SECRET=…` |
| `EnvOptional(x)` | lo mismo que `x`, o `null` si no está | `ISOLATES=4` |

Un valor vacío cuenta como ausente. Solo es público lo que marcas con `public: true`: `env.public` da esas variables, las únicas que puedes poner en una página o pasar a un ViewModel. Un secreto nunca es público.

:::compare
```dart
// WRONG (THOR-P012): the secret in the page
Text('key: ${env.of(AppEnv.session).reveal()}')
```
```dart
// RIGHT: only the public part reaches the page
Text(env.public['SITE_TITLE'] ?? '')
```
:::

Un `Secret` se lee con `reveal()`; al imprimirlo sale `***` y `jsonEncode` falla. Con `thor dev`, una respuesta que contiene el valor de un secreto es un `500` ([THOR-P012](../../errores/THOR-P012.md)), y `thor export` se detiene si una página exportada lo contiene.

`thor dev` y `thor preview` arrancan el servidor con las variables del archivo `.env` de la app; una variable del entorno real tiene prioridad. En producción, configúralas en el hosting ([Compilar y publicar](publicar.md#servidor)).

## Siguientes pasos

:::cards
- [Compilar y publicar](publicar.md) — variables de entorno en el hosting
- [Servidor y acciones](red-y-servidor.md) — acciones y argumentos
- [Formularios](formularios.md) — validación en el navegador y en el servidor
:::
