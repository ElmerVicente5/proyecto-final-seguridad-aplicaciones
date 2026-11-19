# Lista técnica de hallazgos

Consolidado de los hallazgos técnicos encontrados en las fases prácticas, como insumo para que el
equipo documental arme el inventario ISO 27001, el modelo STRIDE/DREAD, la clasificación en las 7
capas y las matrices de riesgo. Cada hallazgo indica su evidencia, la severidad técnica, la capa
sugerida (de las 7 de defensa en profundidad), el elemento STRIDE y su estado.

- **Severidad técnica:** según la herramienta o el impacto demostrado, no es el DREAD final.
- **Capa:** 1 Datos · 2 Aplicación · 3 Host · 4 Red interna · 5 Perímetro · 6 Física · 7 Políticas.
- **Estado:** Corregido (hay versión "después") · Mitigado (control compensatorio, p. ej. WAF) · Abierto.
- **Evidencia:** archivo en `reportes/` o figura del Word de evidencias.

## Fase 2 — Código del plugin (SAST, SCA y pruebas de la API)

| ID | Hallazgo | Severidad | Capa | STRIDE | Estado | Evidencia |
|---|---|---|---|---|---|---|
| H-01 | Inyección SQL en el endpoint `/pedido` (consulta sin preparar) | Alta | 2 | Tampering, Information Disclosure | Corregido (`$wpdb->prepare`) | `reportes/fase2-sast-sca/*_semgrep_*`, `*_codigo_sqli-*` |
| H-02 | XSS reflejado y almacenado en la página de consulta | Alta | 2 | Tampering | Corregido (`esc_html`/`esc_attr`) | `*_codigo_xss-*`, Figuras XSS del Word |
| H-03 | CSRF en el formulario de comentarios (sin nonce) | Media | 2 | Spoofing, Tampering | Corregido (nonce) | `*_codigo_csrf-*`, Figura CSRF |
| H-04 | IDOR: un cliente accede a pedidos de otro | Alta | 2 | Information Disclosure, Elevation of Privilege | Corregido (control de dueño) | `*_pruebas-api_*`, colección Postman |
| H-05 | JWT con clave débil fija en el código y sin expiración | Alta | 1, 2 | Spoofing | Corregido (clave por secreto, `exp`) | `*_codigo_jwt-*` |
| H-06 | Dependencia `firebase/php-jwt` 5.5.1 con CVE-2021-46743 (CRITICAL) | Alta | 2 | Tampering | Corregido (7.2.2) | `reportes/fase2-sast-sca/*_trivy_*`, Code scanning |
| H-07 | Login sin límite de intentos y enumeración de usuarios | Media | 2 | Spoofing | Corregido (bloqueo, mensaje genérico) | colección Postman, `*_pruebas-api_*` |
| H-08 | Exfiltración por paginación sin tope | Media | 2 | Information Disclosure | Corregido (máximo 20) | colección Postman |

## Fase 3 — Pruebas ofensivas (caja negra y gris)

| ID | Hallazgo | Severidad | Capa | STRIDE | Estado | Evidencia |
|---|---|---|---|---|---|---|
| H-09 | MySQL publicado en el anfitrión (puerto 3306) | Media | 4, 5 | Information Disclosure | Corregido (fase 4, puerto cerrado) | `reportes/fase3-pentest/*_nmap_host-*` |
| H-10 | Red Docker plana, sin segmentación entre servicios | Media | 4 | Elevation of Privilege | Corregido (fase 4, red interna) | `*_nmap_red-interna-*` |
| H-11 | Falta de cabeceras de seguridad (CSP, anti-clickjacking, nosniff) | Media | 2, 5 | Tampering | Mitigado (fase 5, mu-plugin) | `*_zap_*`, Figuras ZAP |
| H-12 | `xmlrpc.php` habilitado con `system.multicall` (fuerza bruta amplificada) | Alta | 2, 5 | Spoofing, Denial of Service | Mitigado (fase 5, WAF lo bloquea) | `*_wpscan_fuerza-bruta-*` |
| H-13 | Enumeración de usuarios por API REST y `?author=N` | Media | 2 | Information Disclosure | Mitigado (fase 5, mu-plugin + WAF) | `*_wpscan_enumeracion*`, Postman caja gris |
| H-14 | Divulgación de versiones (Server, X-Powered-By, generator) | Baja | 2, 5 | Information Disclosure | Mitigado (fase 5, WAF + mu-plugin) | `*_nmap_host-*`, `*_waf_pruebas-bloqueo*` |
| H-15 | `wp-cron.php` y `readme.html` accesibles | Baja | 2 | Information Disclosure | Abierto (riesgo aceptado en laboratorio) | `*_wpscan_enumeracion*` |

## Fase 4 — Contenedores e IaC

| ID | Hallazgo | Severidad | Capa | STRIDE | Estado | Evidencia |
|---|---|---|---|---|---|---|
| H-16 | Secretos en variables de entorno (visibles con `docker inspect`) | Alta | 1, 3 | Information Disclosure | Corregido (Docker secrets) | `reportes/fase4-iac/*_kics_*`, comparativo |
| H-17 | Contenedores sin `cap_drop`, `no-new-privileges` ni `read_only` | Media | 3 | Elevation of Privilege | Corregido (hardening) | `*_kics_antes/despues_*` |
| H-18 | Sin límites de CPU, memoria ni PIDs (riesgo de DoS) | Media | 3 | Denial of Service | Corregido (límites) | `*_kics_*`, compose endurecido |
| H-19 | Imágenes sin digest `sha256` y con `WORDPRESS_DEBUG` activo | Baja | 3 | Tampering, Information Disclosure | Corregido (digests, debug off) | `docs/antes-despues/fase4_*` |
| H-20 | CVEs HIGH/CRITICAL del sistema base en las imágenes oficiales | Media | 3 | Tampering | Abierto (dependen del mantenedor de la imagen) | `*_trivy_*_wordpress_*` |

## Fase 5 — Operaciones

| ID | Hallazgo | Severidad | Capa | STRIDE | Estado | Evidencia |
|---|---|---|---|---|---|---|
| H-21 | Ausencia de WAF delante de la aplicación | Alta | 5 | Tampering, Denial of Service | Corregido (ModSecurity + CRS) | `reportes/fase5-operaciones/*_waf_*` |
| H-22 | Sin centralización de logs ni monitoreo (SIEM/RASP) | Media | 7 | Repudiation | Propuesto (conceptual) | `docs/operaciones/rasp-siem.md` |
| H-23 | Índice de la API REST `/wp-json/` público | Baja | 2 | Information Disclosure | Abierto (necesario para la funcionalidad) | Postman caja gris con WAF |

## Resumen por estado

- **Corregido** (con versión "después" o hardening aplicado): H-01 a H-10, H-16 a H-19, H-21.
- **Mitigado** (control compensatorio, principalmente el WAF): H-11 a H-14.
- **Propuesto / Abierto** (riesgo aceptado o pendiente de infraestructura): H-15, H-20, H-22, H-23.
