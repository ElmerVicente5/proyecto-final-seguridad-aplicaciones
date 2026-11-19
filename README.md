# Proyecto Final · Seguridad en Aplicaciones (UMG)

Laboratorio de **WordPress + WooCommerce** en Docker (solo `localhost`) para aplicar un ciclo de
desarrollo seguro: evaluar, atacar, corregir y madurar una aplicación e-commerce
(Opción B de la guía del curso).

> **Nota:** esta es la **línea base ("antes")**, una configuración típica sin hardening y con
> debilidades intencionales marcadas en [docker-compose.yml](docker-compose.yml). No la expongas
> fuera de tu equipo.

## Componentes

| Servicio | Imagen | Función |
|---|---|---|
| `db` | `mysql:8.4.13` | Base de datos (volumen `db_data`, healthcheck) |
| `wordpress` | `wordpress:7.1.4-php8.3-apache` | Sitio en <http://localhost:8080> (volumen `wp_html`) |
| `wpcli` | `wordpress:cli-2.12.0-php8.3` | Administración con WP-CLI (perfil `herramientas`, se usa con `docker compose run`) |
| `composer` | `composer:2.11.2` | Instala las dependencias PHP del plugin propio (perfil `herramientas`) |
| `waf` | `owasp/modsecurity-crs:4.30.0-apache` | WAF (ModSecurity + CRS) como proxy inverso delante de WordPress (fase 5) |

WooCommerce se instala con WP-CLI en la versión fijada en `.env` (`WOOCOMMERCE_VERSION`, por defecto 11.3.0).

## Requisitos

- Windows con **Docker Desktop** (backend WSL2), **Git** (Git Bash) y **VS Code**.
- Puertos libres en el anfitrión: `8080` (WordPress) y `3306` (MySQL; se cambia con `DB_PUERTO_HOST`).

Todos los comandos son de **bash** y se ejecutan en Git Bash desde la raíz del repositorio.

## Levantar el entorno (primera vez)

```bash
# 1. Crear el archivo de variables y cambiar todas las contraseñas de ejemplo
cp .env.example .env
code .env

# 2. Levantar los contenedores e instalar WordPress, WooCommerce, usuarios y datos de ejemplo
./scripts/instalar.sh
```

El script se puede ejecutar varias veces: omite lo que ya existe.

### Qué crea la instalación

| Usuario | Rol | Contraseña (`.env`) |
|---|---|---|
| `admin` (`WP_ADMIN_USER`) | administrator | `WP_ADMIN_PASSWORD` |
| `gestor` | shop_manager (gestor de tienda) | `GESTOR_PASSWORD` |
| `editor` | editor | `EDITOR_PASSWORD` |
| `cliente1`, `cliente2` | customer | `CLIENTE_PASSWORD` |

Con `CREAR_DATOS_EJEMPLO=1` también crea 4 productos y 3 pedidos (uno de `cliente1` y dos de
`cliente2`), útiles para probar BOLA/IDOR entre clientes en la fase 3.

- Tienda: <http://localhost:8080>
- Administración: <http://localhost:8080/wp-admin>
- API REST de WooCommerce: <http://localhost:8080/wp-json/wc/v3/>
- Consulta de pedidos (plugin propio): <http://localhost:8080/consultar-pedido/>
- API REST del plugin: <http://localhost:8080/wp-json/consulta-pedidos/v1/>

## Plugin propio: Consulta de Pedidos

El plugin [plugin-consulta-pedidos/](plugin-consulta-pedidos/) permite que un cliente consulte sus
pedidos por API REST (con token JWT) y desde la página "Consultar pedido", donde también puede dejar
comentarios. Tiene dos versiones con los mismos archivos para compararlas:

| Archivo | `vulnerable/` (antes) | `seguro/` (después) |
|---|---|---|
| `includes/jwt.php` | Clave fija y débil, token sin expiración, confía en el rol del token, php-jwt 5.5.1 con CVE | Clave desde `.env`, expira en 15 min, valida emisor y audiencia, php-jwt 7.2.2 |
| `includes/consultas.php` | SQL concatenado (inyección SQL) | `$wpdb->prepare` y lista blanca para el orden |
| `includes/api.php` | Sin control del dueño del pedido (IDOR), paginación sin tope, login sin límite | Control del dueño, máximo 20 por página, 5 intentos cada 15 min |
| `includes/shortcode.php` | Salida sin escapar (XSS), formulario sin nonce (CSRF) | `esc_html`/`esc_attr`, sanitización y nonce |

Para cambiar de versión, edita `PLUGIN_VERSION` en `.env` (`vulnerable` o `seguro`) y ejecuta:

```bash
docker compose up -d
```

API del plugin:

```bash
API=http://localhost:8080/wp-json/consulta-pedidos/v1
curl -X POST $API/token -d usuario=cliente1 -d clave=<CLIENTE_PASSWORD>   # devuelve un token
curl "$API/pedido?id=14" -H "Authorization: Bearer <token>"
curl "$API/pedidos?pagina=1&por_pagina=10" -H "Authorization: Bearer <token>"
```

## Pruebas de seguridad de la API con Postman

La carpeta [postman/](postman/) tiene la colección `consulta-pedidos.postman_collection.json` y el
entorno `laboratorio-localhost.postman_environment.json`. Cada prueba describe el comportamiento
seguro esperado, así que **en la versión vulnerable fallan 12 de 21 aserciones** (una por cada
vulnerabilidad) y **en la segura pasan todas**.

| Carpeta | Pruebas |
|---|---|
| 1. Autenticación | Token con expiración y sin datos personales, enumeración de usuarios |
| 2. Control de acceso | Pedido propio sin datos sensibles, IDOR sobre el pedido de otro cliente |
| 3. Inyección SQL | `UNION SELECT` sobre `wp_users` |
| 4. Manejo de tokens JWT | Token falsificado con la clave débil y rol de administrador |
| 5. Casos de abuso | Exfiltración por paginación y fuerza bruta (7 intentos) |

En la app de Postman: **Import** de los dos archivos, selecciona el entorno **Laboratorio localhost**,
escribe la contraseña de `cliente1` (`CLIENTE_PASSWORD` del `.env`) en `clave_cliente` y ejecuta la
colección con **Run collection**.

Desde la terminal con la CLI de Postman:

```bash
postman collection run postman/consulta-pedidos.postman_collection.json \
  -e postman/laboratorio-localhost.postman_environment.json \
  --env-var "clave_cliente=$(grep '^CLIENTE_PASSWORD=' .env | cut -d= -f2)"
```

La prueba de fuerza bruta deja bloqueada la cuenta `gestor` 15 minutos en la versión segura. Para
repetir la colección antes de ese tiempo, borra los bloqueos con:

```bash
docker compose run --rm wpcli wp transient delete --all
```

## Reproducir los escaneos

Todas las herramientas de seguridad corren en **Docker**, así que un compañero que clona el repo no
necesita instalar nada más (ni ZAP, ni Nmap, ni Semgrep): solo Docker, la CLI de Postman y un `.env`.
Hay un punto de entrada único por fase:

```bash
./scripts/reproducir.sh fase2    # SAST (Semgrep) y SCA (Trivy) del plugin
./scripts/reproducir.sh fase3    # Nmap, ZAP, WPScan y Postman (contra la línea base)
./scripts/reproducir.sh fase4    # Trivy (imágenes) y KICS (compose), antes y después
./scripts/reproducir.sh fase5    # pruebas de bloqueo del WAF
```

Cada escaneo guarda su salida en `reportes/<fase>/`, y los reportes HTML (Trivy, KICS, ZAP) en
`reportes/<fase>/html/` para abrirlos en el navegador.

### Estados del entorno (antes / después)

El proyecto endurece la aplicación en tres estados. Para reproducir una fase o mostrar el
antes/después hay que levantar el entorno en el estado correspondiente:

```bash
./scripts/levantar-estado.sh linea-base   # vulnerable, sin WAF        -> fases 1, 2 y 3
./scripts/levantar-estado.sh endurecido   # Docker secrets, hardening  -> fase 4
./scripts/levantar-estado.sh waf          # endurecido + WAF (final)    -> fase 5
```

Las mismas pruebas dan resultados distintos según el estado, y eso **es** el antes/después. Por
ejemplo, el mismo ataque de SQLi responde `200` en la línea base (llega a WordPress) y `403` con el
WAF. `docker compose up` por sí solo levanta el estado final (con WAF). El plugin (`vulnerable` o
`seguro`) se elige aparte con `PLUGIN_VERSION` en `.env`.

## Operaciones: WAF y hardening (fase 5)

Un **WAF** (ModSecurity + OWASP Core Rule Set, imagen `owasp/modsecurity-crs`) se coloca como proxy
inverso: publica `127.0.0.1:8080` y reenvía a WordPress, que deja de exponerse. Todo el tráfico pasa
por el WAF.

```bash
docker compose up -d        # levanta db, wordpress y waf
curl -I http://localhost:8080/                         # 200, Server: UMG-WAF
curl -o /dev/null -w "%{http_code}\n" "http://localhost:8080/?id=1%27%20UNION%20SELECT%201--"   # 403
```

- **WAF** ([waf/rules/999-umg-custom.conf](waf/rules/999-umg-custom.conf)): el CRS bloquea SQLi, XSS y
  path traversal; reglas propias bloquean `xmlrpc.php` y la enumeración por `?author=N`, y ocultan las
  cabeceras `Server` y `X-Powered-By`.
- **mu-plugin** ([mu-plugins/umg-hardening.php](mu-plugins/umg-hardening.php)): añade cabeceras de
  seguridad (CSP, `X-Frame-Options`, `nosniff`, `Referrer-Policy`), oculta la versión de WordPress y
  cierra la enumeración de usuarios por la API REST.
- **RASP y SIEM**: propuesta conceptual con configuración de ejemplo en
  [docs/operaciones/rasp-siem.md](docs/operaciones/rasp-siem.md) y
  [waf/siem/fluent-bit.conf.ejemplo](waf/siem/fluent-bit.conf.ejemplo). El audit log de ModSecurity
  (en JSON, por la salida estándar del contenedor `waf`) es la fuente de eventos.

Con el WAF y el mu-plugin, la colección de caja gris de la fase 3 pasa de 10 aserciones fallidas a 1.
Las dos versiones del compose se conservan en `docs/antes-despues/` (`fase5_...`).

## Auditoría de contenedores e IaC (fase 4)

La configuración de Docker se audita y se endurece, con reporte **antes y después** en
`reportes/fase4-iac/`. Las dos versiones del compose se conservan en
[docs/antes-despues/](docs/antes-despues/) (`fase4_docker-compose.antes.yml` y `.despues.yml`).

- **Trivy** escanea las imágenes (`mysql`, `wordpress`, `wordpress:cli`) en busca de CVE del sistema base.
- **KICS** audita el `docker-compose.yml` (Checkov ya no soporta compose, por eso se usa KICS).

```bash
./scripts/escanear-fase4.sh antes     # o: despues
```

Hardening aplicado al compose (bajó los hallazgos de KICS de 26 a 12, y los de severidad alta a 0):
contraseñas por **Docker secrets** (`_FILE`), `cap_drop: ALL` con capacidades mínimas,
`no-new-privileges`, `read_only` con `tmpfs`, límites de CPU/memoria/PIDs, healthcheck,
imágenes fijadas por **digest sha256**, MySQL sin publicar en el anfitrión, red `backend` interna y
`WORDPRESS_DEBUG` apagado. Los secretos se generan desde `.env` con `scripts/generar-secretos.sh`
(lo hace `instalar.sh`) y quedan en `secrets/` (fuera del repo).

## Pruebas ofensivas (fase 3)

Todas las pruebas se hacen contra la línea base vulnerable en `localhost`. Las herramientas se
ejecutan desde la terminal y guardan sus reportes en `reportes/fase3-pentest/`.

| Prueba | Herramienta | Comando |
|---|---|---|
| Puertos del anfitrión | Nmap | `nmap -sV -p 8080,3306 127.0.0.1` |
| Red interna de Docker | Nmap en contenedor | `docker run --rm --network umg-wp-ecommerce_default instrumentisto/nmap -sV -sC 172.19.0.2,3` |
| Escaneo web de caja negra | OWASP ZAP | `./scripts/escanear-zap.sh` |
| Enumeración de WordPress | WPScan | `docker run --rm --network host wpscanteam/wpscan --url http://localhost:8080 --enumerate u,cb,dbe --plugins-detection passive` |
| APIs nativas (caja gris) | Postman | `postman collection run postman/wordpress-woocommerce-api.postman_collection.json -e postman/laboratorio-localhost.postman_environment.json` |

`scripts/escanear-zap.sh` corre ZAP en Docker (`zaproxy/zap-stable`) con el plan
[scripts/zap/plan-caja-negra.yaml](scripts/zap/plan-caja-negra.yaml); no hace falta instalar ZAP.
`scripts/escanear-nmap.sh` hace lo mismo con Nmap en Docker.

El escaneo activo de ZAP envía miles de peticiones y **ensucia la base de datos**. Al terminar la
fase 3, reinicia el entorno desde cero:

```bash
docker compose down -v && ./scripts/instalar.sh
```

El mapa de superficie de ataque está en
[docs/arquitectura/mapa-superficie-ataque.drawio](docs/arquitectura/mapa-superficie-ataque.drawio)
(se abre en <https://app.diagrams.net> o con la extensión de draw.io en VS Code).

## Pipeline DevSecOps

[.github/workflows/devsecops.yml](.github/workflows/devsecops.yml) se ejecuta en GitHub Actions en
cada push a `main` y en cada pull request:

- **SAST con Semgrep:** reglas propias para WordPress ([.semgrep/wordpress.yml](.semgrep/wordpress.yml))
  más los conjuntos `p/php`, `p/owasp-top-ten` y `p/secrets`.
- **SCA con Trivy:** busca CVE en las dependencias declaradas en `composer.lock`.

Ambos analizan las dos versiones del plugin. La versión **segura** es la barrera: si tiene hallazgos
ERROR o vulnerabilidades HIGH/CRITICAL el pipeline falla. En la vulnerable solo se reportan. Los
resultados quedan en el resumen de cada ejecución, como artefactos descargables y en
**Security → Code scanning**.

Para correr los mismos análisis en local y guardar los reportes en `reportes/fase2-sast-sca/`:

```bash
./scripts/escanear-fase2.sh
```

## Verificar

```bash
docker compose ps                                     # db "healthy", wordpress "Up"
curl -I http://localhost:8080                         # debe responder HTTP 200
docker compose run --rm wpcli wp plugin list          # woocommerce: active
docker compose run --rm wpcli wp user list --fields=user_login,roles
```

## Uso diario

```bash
docker compose up -d          # iniciar (los datos se conservan en los volúmenes)
docker compose stop           # detener sin borrar contenedores
docker compose down           # detener y borrar contenedores (los volúmenes se conservan)
docker compose logs -f wordpress
```

Cualquier comando de WP-CLI:

```bash
docker compose run --rm wpcli wp wc product list --user=admin --fields=id,name,price
```

En Git Bash, los comandos que pasan rutas del contenedor (por ejemplo `/scripts/...`) necesitan
`MSYS_NO_PATHCONV=1` delante para que no se conviertan en rutas de Windows. `instalar.sh` ya lo hace.

## Reiniciar desde cero

**Atención:** esto borra todos los datos (base de datos y archivos de WordPress).

```bash
docker compose down -v        # elimina contenedores y los volúmenes db_data y wp_html
./scripts/instalar.sh         # vuelve a levantar e instalar todo
```

## Estructura del repositorio

```
├── docker-compose.yml         # línea base: WordPress + MySQL + WP-CLI
├── .env.example               # plantilla de variables (el .env real no se versiona)
├── scripts/
│   ├── instalar.sh            # levanta el entorno y lanza la instalación
│   ├── instalar-wordpress.sh  # instalación con WP-CLI (corre dentro del contenedor wpcli)
│   └── escanear-fase2.sh      # SAST y SCA en local
├── plugin-consulta-pedidos/   # plugin propio: vulnerable/ y seguro/ (fase 2)
├── postman/                   # colecciones y entorno de pruebas de seguridad de la API
├── docs/arquitectura/         # mapa de superficie de ataque (draw.io)
├── .semgrep/                  # reglas propias de Semgrep para WordPress
├── .github/workflows/         # pipeline DevSecOps (fase 2)
├── waf/                       # ModSecurity + OWASP CRS (fase 5)
├── reportes/                  # salidas de herramientas por fase
└── docs/                      # diagramas de arquitectura y lista técnica de hallazgos
```

## Debilidades intencionales de la línea base

Marcadas en [docker-compose.yml](docker-compose.yml) con comentarios `Vulnerable intencional: ...`.
Se auditarán con Checkov y Trivy y se corregirán en la fase 4.

| # | Debilidad | Servicio |
|---|---|---|
| 1 | Imágenes fijadas por etiqueta pero no por digest `sha256` | db, wordpress |
| 2 | Secretos en variables de entorno (visibles con `docker inspect`) en lugar de Docker secrets | db, wordpress |
| 3 | MySQL publicado en el anfitrión sin necesidad | db |
| 4 | Sin límites de CPU, memoria ni PIDs | db, wordpress |
| 5 | Sin `no-new-privileges`, `cap_drop` ni sistema de archivos `read_only` | db, wordpress |
| 6 | Apache arranca como root | wordpress |
| 7 | `WORDPRESS_DEBUG` activo: muestra errores PHP | wordpress |
| 8 | Solo HTTP, sin TLS, sin cabeceras de seguridad y sin WAF | wordpress |
| 9 | Red plana sin segmentación entre servicios | todos |
| 10 | `xmlrpc.php` y la API REST habilitados por defecto (se explotan en la fase 3) | wordpress |

## Reglas del laboratorio

- Todas las pruebas se hacen **solo** contra `localhost` / los contenedores de este proyecto.
- No subas `.env` ni secretos al repositorio.
