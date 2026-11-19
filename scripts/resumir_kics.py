"""Imprime un resumen legible del results.json de KICS.

Uso: python scripts/resumir_kics.py <ruta results.json>
"""

import json
import sys
from pathlib import Path

ORDEN = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4, "TRACE": 5}

ruta = Path(sys.argv[1])
if not ruta.is_file():
    print(f"\nNo se encontró {ruta}")
    sys.exit(0)

datos = json.loads(ruta.read_text(encoding="utf-8"))
conteo = datos.get("severity_counters", {})

print("\nResumen KICS sobre docker-compose.yml")
print("Total de hallazgos:", datos.get("total_counter", 0))
print("Por severidad:", ", ".join(f"{s}: {conteo.get(s, 0)}" for s in ORDEN if conteo.get(s)))
print()
print(f"{'Severidad':10} {'Hallazgo':48} Servicios/lineas afectados")
for q in sorted(datos.get("queries", []), key=lambda x: ORDEN.get(x.get("severity", ""), 9)):
    lineas = ", ".join(str(f.get("line")) for f in q.get("files", []))
    print(f"{q['severity']:10} {q['query_name'][:48]:48} {lineas}")
