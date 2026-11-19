# Respaldos antes / después

Cada cambio importante de configuración se conserva aquí como dos archivos congelados, para que el
equipo documental pueda comparar el "antes" y el "después" sin navegar el historial de git.

Convención de nombres: `faseN_<artefacto>.antes.<ext>` y `faseN_<artefacto>.despues.<ext>`.

| Fase | Artefacto | Antes | Después |
|---|---|---|---|
| 4 | docker-compose.yml | `fase4_docker-compose.antes.yml` (línea base sin hardening) | `fase4_docker-compose.despues.yml` (endurecido) |

El estado vigente, que es el que realmente se ejecuta, siempre vive en su ubicación normal
(por ejemplo `docker-compose.yml` en la raíz). Estos archivos son copias de solo lectura para
documentar; no se usan para levantar el entorno.

Otros antes/después que no están aquí porque ya se separan por carpeta o por herramienta:

- **Plugin propio:** `plugin-consulta-pedidos/vulnerable/` y `plugin-consulta-pedidos/seguro/`.
- **Reportes de escaneo:** `reportes/fase4-iac/` guarda los reportes `_antes_` y `_despues_` de Trivy y KICS.
