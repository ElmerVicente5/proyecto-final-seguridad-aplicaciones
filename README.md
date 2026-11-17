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
│   └── instalar-wordpress.sh  # instalación con WP-CLI (corre dentro del contenedor wpcli)
├── plugin-consulta-pedidos/   # plugin propio: vulnerable/ y seguro/ (fase 2)
├── .github/workflows/         # pipeline DevSecOps (fase 2)
├── waf/                       # ModSecurity + OWASP CRS (fase 5)
├── reportes/                  # salidas de herramientas por fase
├── evidencias/                # capturas y registro de evidencias
├── docs/                      # diagramas, inventario, STRIDE/DREAD, matrices
└── informe/                   # informe final
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
