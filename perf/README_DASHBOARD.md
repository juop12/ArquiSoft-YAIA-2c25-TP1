# Dashboard de Grafana para arVault Exchange Service

## Descripción

Este dashboard de Grafana ha sido diseñado específicamente para el análisis de atributos de calidad del servicio de cambio de monedas de arVault, cumpliendo con los requerimientos del Trabajo Práctico 1 de Arquitectura del Software.

## Características Principales

### ✅ Métricas Requeridas por el Fundador
- **Volumen operado por moneda**: Tracking de compras y ventas sumadas por cada moneda
- **Neto por moneda**: Posición neta donde compras suman y ventas restan

### 📊 Métricas de Performance
- Throughput (RPS) de escenarios de prueba
- Tiempo de respuesta (percentiles 50, 95, máximo)
- Distribución de estados de requests
- Duración de operaciones de cambio

### 💼 Métricas de Negocio
- Tasa de éxito de intercambios
- Tasas de cambio en tiempo real
- Volumen de trading por moneda
- Posición neta por moneda

### 🖥️ Métricas de Sistema
- Uso de CPU y memoria
- Recursos del contenedor

## Instalación y Configuración

### 1. Levantar los Servicios

```bash
# Desde el directorio raíz del proyecto
docker-compose up -d
```

### 2. Instalar Dependencias

```bash
# Instalar dependencias de la aplicación
cd app
npm install

# Instalar dependencias de performance testing
cd ../perf
npm install
```

### 3. Importar el Dashboard

```bash
# Ejecutar el script de importación
./perf/import-dashboard.sh
```

### 4. Acceder a Grafana

- URL: http://localhost
- Usuario: admin
- Contraseña: admin

## Uso del Dashboard

### Paneles Principales

1. **Scenarios Launched (RPS)**: Muestra el throughput de las pruebas de carga
2. **Request Status Distribution**: Distribución de estados de las requests
3. **Response Time (Client-side)**: Latencia desde la perspectiva del cliente
4. **System Resources**: Uso de CPU y memoria del sistema
5. **Trading Volume by Currency**: Volumen operado por cada moneda
6. **Net Position by Currency**: Posición neta por moneda
7. **Exchange Success Rate**: Tasa de éxito de las operaciones
8. **Exchange Rates**: Tasas de cambio actuales
9. **Exchange Operation Duration**: Duración de las operaciones (server-side)

### Variables de Template

- **$server**: Selecciona el servidor de métricas (artillery-exchange)
- **$container**: Selecciona el contenedor a monitorear

### Configuración de Tiempo

- **Rango por defecto**: Últimos 5 minutos
- **Refresh rate**: 5 segundos
- **Opciones de tiempo**: 5m, 15m, 1h, 6h, 12h, 24h, 2d, 7d, 30d

## Ejecución de Pruebas

### 1. Prueba Básica de Carga

```bash
# Ejecutar escenario de intercambio
./perf/run-scenario.sh exchange-scenario api
```

### 2. Prueba de Estrés

```bash
# Ejecutar prueba de estrés
./perf/run-scenario.sh stress-test api
```

### 3. Prueba de Volumen

```bash
# Ejecutar prueba de volumen
./perf/run-scenario.sh volume-test api
```

### 4. Probar Métricas Personalizadas

```bash
# Ejecutar script de prueba de métricas
cd perf
node test-custom-metrics.js
```

## Análisis de Atributos de Calidad

### Performance
- **Throughput**: Observar "Scenarios Launched (RPS)"
- **Latencia**: Analizar "Response Time" y "Exchange Operation Duration"
- **Utilización de recursos**: Monitorear "System Resources"

### Reliability
- **Tasa de errores**: Revisar "Request Status Distribution"
- **Tasa de éxito**: Observar "Exchange Success Rate"

### Scalability
- **Correlación carga-recursos**: Comparar RPS con uso de CPU/memoria
- **Punto de saturación**: Identificar cuando la latencia aumenta significativamente

### Business Metrics
- **Volumen de operaciones**: "Trading Volume by Currency"
- **Gestión de riesgo**: "Net Position by Currency"
- **Calidad del servicio**: "Exchange Success Rate"

## Troubleshooting

### Las métricas personalizadas no aparecen
1. Verificar que la aplicación esté enviando métricas a StatsD
2. Comprobar la conectividad entre la app y Graphite
3. Ejecutar el script de prueba: `node test-custom-metrics.js`

### El dashboard no se carga
1. Verificar que Grafana esté ejecutándose: `docker-compose ps`
2. Comprobar que Graphite esté disponible: `curl http://localhost:8090`
3. Revisar los logs: `docker-compose logs grafana`

### Datos no se actualizan
1. Verificar el refresh rate del dashboard
2. Comprobar que las pruebas estén ejecutándose
3. Revisar la configuración de StatsD

## Personalización

### Agregar Nuevas Métricas
1. Modificar `app/exchange.js` para enviar nuevas métricas
2. Actualizar el dashboard JSON con nuevos paneles
3. Reimportar el dashboard

### Modificar Visualizaciones
1. Editar el archivo `dashboard.json`
2. Usar la interfaz de Grafana para ajustes menores
3. Exportar la configuración actualizada

## Archivos Importantes

- `dashboard.json`: Configuración del dashboard de Grafana
- `DASHBOARD_METRICS.md`: Documentación detallada de métricas
- `test-custom-metrics.js`: Script de prueba para métricas personalizadas
- `import-dashboard.sh`: Script de importación automática

## Notas para el TP

Este dashboard cumple con los requerimientos específicos del enunciado:

1. ✅ **Métricas de volumen por moneda** (requerimiento obligatorio del fundador)
2. ✅ **Métricas de neto por moneda** (requerimiento obligatorio del fundador)
3. ✅ **Métricas de performance** para análisis de QA
4. ✅ **Métricas de recursos** para análisis de escalabilidad
5. ✅ **Métricas de negocio** específicas del servicio de cambio

El dashboard está optimizado para capturar screenshots que demuestren el impacto de las tácticas implementadas en los atributos de calidad del sistema.
