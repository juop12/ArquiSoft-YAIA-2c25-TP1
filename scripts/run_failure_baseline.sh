#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
SERVICE="${SERVICE:-api}"                                  # nombre del servicio en docker-compose.yml
HEALTH_URL="${HEALTH_URL:-http://localhost:5555/rates}"    # endpoint para marcar RECOVERED
RAMP_SECONDS="${RAMP_SECONDS:-30}"                         # duración de la fase Ramp del YAML
CUT_OFFSET_IN_PLAIN="${CUT_OFFSET_IN_PLAIN:-30}"           # segundos dentro de Plain antes de cortar
DOWN_FOR="${DOWN_FOR:-30}"                                 # mantener la API abajo N s (por defecto 30)

OUTDIR="results_failure_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

log(){ echo "[$(date +%T)] $*"; }
ts(){ date +%T; }
epoch(){ date +%s; }

# --- elegir docker compose ---
if command -v docker compose >/dev/null 2>&1; then
  DC="docker compose"
else
  DC="docker-compose"
fi

# ==== Prechequeos ====
[[ -x "./scripts/run-scenario.sh" ]] || { echo "No encuentro ./scripts/run-scenario.sh (raíz)."; exit 1; }
[[ -f "./perf/scenarios/rates.yaml" ]] || { echo "No encuentro ./perf/scenarios/rates.yaml (raíz)."; exit 1; }
command -v curl >/dev/null || { echo "curl no encontrado."; exit 1; }

# ==== 1) Iniciar carga dentro de perf/ ====
log "Preparando perf/ y lanzando ./scripts/run-scenario.sh rates api…"
(
  set -euo pipefail
  cd perf
  if [[ ! -d node_modules ]]; then
    npm ci --silent || npm install --silent
  fi
  ../scripts/run-scenario.sh rates api 2>&1 | tee "../$OUTDIR/artillery.log"
) & ART_PID=$!

sleep 2
kill -0 "$ART_PID" 2>/dev/null || { echo "El escenario no arrancó (ver $OUTDIR/artillery.log)."; exit 1; }

# ==== 2) Esperar Plain y cortar ====
sleep "$RAMP_SECONDS"
log "Entró Plain; espero $CUT_OFFSET_IN_PLAIN s y corto el servicio…"
sleep "$CUT_OFFSET_IN_PLAIN"

# id del contenedor del servicio
CID=$($DC ps -q "$SERVICE")
[[ -n "${CID:-}" ]] || { echo "No encuentro contenedor para el servicio '$SERVICE'."; exit 1; }

FAIL_ON="$(ts)"; FAIL_ON_EPOCH="$(epoch)"
log "FAIL_ON $FAIL_ON → $DC stop $SERVICE"
$DC stop "$SERVICE" >/dev/null

# esperar a que realmente esté detenido
log "Esperando a que el contenedor se detenga…"
for i in {1..30}; do
  RUNNING=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo "false")
  [[ "$RUNNING" == "false" ]] && break
  sleep 1
done

# mantener abajo
if (( DOWN_FOR > 0 )); then
  log "Manteniendo API abajo por $DOWN_FOR s…"
  sleep "$DOWN_FOR"
fi

# ==== 3) Levantar y esperar recuperación ====
RECOVERY_START="$(ts)"; RECOVERY_START_EPOCH="$(epoch)"
log "RECOVERY_START $RECOVERY_START → $DC start $SERVICE"
$DC start "$SERVICE" >/dev/null

log "Esperando RECOVERED (HTTP 200 en $HEALTH_URL)…"
until curl -fsS "$HEALTH_URL" >/dev/null; do sleep 1; done
RECOVERED="$(ts)"; RECOVERED_EPOCH="$(epoch)"
log "RECOVERED $RECOVERED"

# ==== 4) Cerrar carga ====
wait "$ART_PID" || true

# ==== 5) Timestamps ====
{
  echo "FAIL_ON $FAIL_ON"
  echo "RECOVERY_START $RECOVERY_START"
  echo "RECOVERED $RECOVERED"
} | tee "$OUTDIR/timestamps.log"

# ==== 6) Downtime y MTTR ====
DOWNTIME=$(( RECOVERED_EPOCH - FAIL_ON_EPOCH ))
MTTR=$(( RECOVERED_EPOCH - RECOVERY_START_EPOCH ))

# ==== 7) Disponibilidad desde el Summary ====
TOTAL_REQ=$(grep -E "http\.requests:\s" "$OUTDIR/artillery.log" | tail -1 | awk '{print $NF}')
[[ -z "${TOTAL_REQ:-}" ]] && TOTAL_REQ=$(grep -E "http\.responses:\s" "$OUTDIR/artillery.log" | tail -1 | awk '{print $NF}')
OK_200=$(grep -E "http\.codes\.200:\s" "$OUTDIR/artillery.log" | tail -1 | awk '{print $NF}')
if [[ -n "${TOTAL_REQ:-}" && -n "${OK_200:-}" ]]; then
  DISP=$(python3 - <<EOF
ok=int("$OK_200"); tot=int("$TOTAL_REQ")
print(f"{(ok/tot)*100:.2f}" if tot>0 else "NA")
EOF
)
else
  DISP="NA"
fi

# ==== 8) Resumen ====
{
  echo "==== Failure baseline ===="
  echo "Command: (cd perf && ../scripts/run-scenario.sh rates api)"
  echo "FAIL_ON: $FAIL_ON"
  echo "RECOVERY_START: $RECOVERY_START"
  echo "RECOVERED: $RECOVERED"
  echo "Downtime (s): $DOWNTIME"
  echo "MTTR (s): $MTTR"
  echo "Disponibilidad estimada (%): $DISP"
} | tee "$OUTDIR/summary.txt"

log "Listo ✅ Resultados en: $OUTDIR"
