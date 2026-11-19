# RASP y SIEM (propuesta conceptual, fase 5)

El WAF (ModSecurity + CRS) ya está implementado y funcionando delante de WordPress. RASP y SIEM se
entregan como propuesta conceptual con configuración de ejemplo, como acordó el equipo.

## SIEM: centralización de logs

**Fuente de datos:** ModSecurity escribe su audit log en formato JSON a la salida estándar del
contenedor `waf` (`MODSEC_AUDIT_LOG=/dev/stdout`). Cada ataque bloqueado es un evento con la regla
que lo detectó, la puntuación de anomalía, la IP de origen y la petición completa. Ejemplo real en
`reportes/fase5-operaciones/*_waf_modsecurity-audit-log.txt`.

**Recolección:** un agente ligero (Fluent Bit, Filebeat o el agente de Wazuh) lee los logs del
contenedor, filtra los eventos de seguridad y los reenvía al SIEM. Configuración de ejemplo en
[../../waf/siem/fluent-bit.conf.ejemplo](../../waf/siem/fluent-bit.conf.ejemplo).

**Correlación y alertas en el SIEM:**

| Regla de correlación | Qué detecta |
|---|---|
| Más de N eventos 403 del WAF desde una misma IP en 1 minuto | Escaneo automatizado o ataque en curso |
| Varios `id "10001"` (xmlrpc) o `id "10002"` (author) seguidos | Intento de enumeración o fuerza bruta |
| Picos de anomalía CRS sobre un mismo endpoint | Fuzzing dirigido |
| Login de administrador fuera de horario | Acceso sospechoso |

Fuentes a centralizar: audit log del WAF, `access.log` de Apache, logs de MySQL y los eventos de
autenticación de WordPress.

## RASP: monitoreo en tiempo de ejecución

Un WAF filtra en el perímetro; un RASP observa desde dentro de la aplicación y entiende el contexto
(qué usuario, qué consulta SQL, qué pedido). Para esta tienda se propone:

- **Monitoreo de la API del plugin:** registrar cada acceso a `/wp-json/consulta-pedidos/v1/pedido`
  con el usuario del token y el pedido solicitado, y alertar cuando un cliente pide pedidos que no
  son suyos (patrón de IDOR) o recorre IDs de forma secuencial.
- **Detección de anomalías de consulta:** alertar si una consulta a la base de datos devuelve muchas
  más filas de lo normal (señal de exfiltración por paginación).
- **Límite de tasa por usuario** en los endpoints sensibles, además del límite por IP del WAF.

Herramientas candidatas: un plugin de seguridad de WordPress con módulo RASP, o una librería RASP a
nivel de PHP. En este proyecto queda como diseño; la base de telemetría ya existe en el audit log del
WAF y en los logs de la aplicación.
