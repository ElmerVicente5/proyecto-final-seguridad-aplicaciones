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
├── postman/                   # colección y entorno de pruebas de seguridad de la API
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
