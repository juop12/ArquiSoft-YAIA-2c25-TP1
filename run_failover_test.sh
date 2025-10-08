#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
SERVICE="${SERVICE:-api}"                                  # nombre del servicio principal
BACKUP_SERVICE="${BACKUP_SERVICE:-api-backup}"            # nombre del servicio backup
HEALTH_URL="${HEALTH_URL:-http://localhost:5555/health}"   # endpoint para verificar salud
RAMP_SECONDS="${RAMP_SECONDS:-30}"                         # duración de la fase Ramp del YAML
CUT_OFFSET_IN_PLAIN="${CUT_OFFSET_IN_PLAIN:-30}"           # segundos dentro de Plain antes de cortar
DOWN_FOR="${DOWN_FOR:-20}"                                 # mantener la API principal abajo N s

OUTDIR="results_failover_$(date +%Y%m%d_%H%M%S)"
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
[[ -x "./perf/run-scenario.sh" ]] || { echo "No encuentro ./perf/run-scenario.sh (raíz)."; exit 1; }
[[ -f "./perf/rates.yaml" ]] || { echo "No encuentro ./perf/rates.yaml (raíz)."; exit 1; }
command -v curl >/dev/null || { echo "curl no encontrado."; exit 1; }

# ==== 1) Levantar todos los contenedores ====
log "Levantando todos los contenedores con failover..."
$DC up -d

log "Esperando que los servicios estén listos (10s)..."
sleep 10

# Verificar que ambos contenedores estén corriendo
log "Verificando estado de contenedores..."
$DC ps

# Verificar que el servicio principal responde
log "Verificando que el servicio principal responde..."
for i in {1..10}; do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    log "✓ Servicio principal funcionando"
    break
  fi
  if [ $i -eq 10 ]; then
    log "✗ Servicio principal no responde después de 10 intentos"
    exit 1
  fi
  sleep 2
done

# ==== 2) Iniciar carga dentro de perf/ ====
log "Iniciando prueba de carga con Artillery..."
(
  set -euo pipefail
  cd perf
  if [[ ! -d node_modules ]]; then
    npm ci --silent || npm install --silent
  fi
  ./run-scenario.sh rates api 2>&1 | tee "../$OUTDIR/artillery.log"
) & ART_PID=$!

sleep 2
kill -0 "$ART_PID" 2>/dev/null || { echo "El escenario no arrancó (ver $OUTDIR/artillery.log)."; exit 1; }

# ==== 3) Esperar Plain y cortar servicio principal ====
sleep "$RAMP_SECONDS"
log "Entró Plain; espero $CUT_OFFSET_IN_PLAIN s y corto el servicio principal…"
sleep "$CUT_OFFSET_IN_PLAIN"

# id del contenedor del servicio principal
CID=$($DC ps -q "$SERVICE")
[[ -n "${CID:-}" ]] || { echo "No encuentro contenedor para el servicio '$SERVICE'."; exit 1; }

FAIL_ON="$(ts)"; FAIL_ON_EPOCH="$(epoch)"
log "FAIL_ON $FAIL_ON → $DC stop $SERVICE (simulando falla del principal)"
$DC stop "$SERVICE" >/dev/null

# esperar a que realmente esté detenido
log "Esperando a que el contenedor principal se detenga…"
for i in {1..30}; do
  RUNNING=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo "false")
  [[ "$RUNNING" == "false" ]] && break
  sleep 1
done

# ==== 4) Verificar que el backup está funcionando ====
log "Verificando que el backup está manejando el tráfico..."
BACKUP_ACTIVE="$(ts)"
sleep 3  # Dar tiempo a nginx para detectar el cambio
for i in {1..15}; do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    log "✓ Backup activo y respondiendo (intento $i)"
    break
  fi
  if [ $i -eq 15 ]; then
    log "✗ Backup no está respondiendo después de 15 intentos"
    log "Verificando estado de contenedores:"
    docker ps | grep exchange-api
    # Continuar de todas formas para ver el reporte
  fi
  sleep 1
done

# mantener principal abajo por un tiempo
if (( DOWN_FOR > 0 )); then
  log "Manteniendo principal abajo por $DOWN_FOR s para probar el backup..."
  sleep "$DOWN_FOR"
fi

# ==== 5) Levantar principal y esperar recuperación automática ====
RECOVERY_START="$(ts)"; RECOVERY_START_EPOCH="$(epoch)"
log "RECOVERY_START $RECOVERY_START → $DC start $SERVICE (recuperación automática)"
$DC start "$SERVICE" >/dev/null

log "Esperando que el principal se recupere automáticamente..."
# Esperar a que el principal esté corriendo
for i in {1..30}; do
  RUNNING=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo "false")
  [[ "$RUNNING" == "true" ]] && break
  sleep 1
done

# Esperar a que responda
for i in {1..20}; do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    log "✓ Principal recuperado y respondiendo"
    break
  fi
  if [ $i -eq 20 ]; then
    log "⚠ Principal no responde después de 20 intentos, pero continuando..."
  fi
  sleep 1
done

RECOVERED="$(ts)"; RECOVERED_EPOCH="$(epoch)"
log "RECOVERED $RECOVERED"

# ==== 6) Cerrar carga ====
log "Cerrando prueba de carga..."
wait "$ART_PID" || true

# ==== 7) Timestamps ====
{
  echo "FAIL_ON $FAIL_ON"
  echo "BACKUP_ACTIVE $BACKUP_ACTIVE"
  echo "RECOVERY_START $RECOVERY_START"
  echo "RECOVERED $RECOVERED"
} | tee "$OUTDIR/timestamps.log"

# ==== 8) Cálculos de tiempo ====
DOWNTIME=$(( RECOVERED_EPOCH - FAIL_ON_EPOCH ))
MTTR=$(( RECOVERED_EPOCH - RECOVERY_START_EPOCH ))
BACKUP_TIME=$(( RECOVERED_EPOCH - $(date -d "$BACKUP_ACTIVE" +%s 2>/dev/null || echo $RECOVERY_START_EPOCH) ))

# ==== 9) Disponibilidad desde Artillery ====
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

# ==== 10) Estado final de contenedores ====
log "Estado final de contenedores:"
$DC ps | tee "$OUTDIR/containers_final.log"

# ==== 11) Resumen ====
{
  echo "==== Failover Test Results ===="
  echo "Command: (cd perf && ./run-scenario.sh rates api)"
  echo "FAIL_ON: $FAIL_ON (principal detenido)"
  echo "BACKUP_ACTIVE: $BACKUP_ACTIVE (backup tomó control)"
  echo "RECOVERY_START: $RECOVERY_START (principal reiniciado)"
  echo "RECOVERED: $RECOVERED (sistema completamente recuperado)"
  echo ""
  echo "Métricas de Failover:"
  echo "Downtime total (s): $DOWNTIME"
  echo "MTTR - Mean Time To Recovery (s): $MTTR"
  echo "Tiempo de backup activo (s): $BACKUP_TIME"
  echo "Disponibilidad estimada (%): $DISP"
  echo ""
  echo "Contenedores:"
  echo "- Principal: $SERVICE"
  echo "- Backup: $BACKUP_SERVICE"
  echo "- Load Balancer: nginx"
  echo ""
  echo "Archivos generados:"
  echo "- artillery.log: Log completo de Artillery"
  echo "- timestamps.log: Timestamps de eventos"
  echo "- containers_final.log: Estado final de contenedores"
} | tee "$OUTDIR/summary.txt"

log "✅ Prueba de failover completada"
log "📊 Resultados en: $OUTDIR"
log "📈 Ver summary.txt para métricas detalladas"
