# Dashboard de Métricas - arVault Exchange Service

## Descripción General

Este dashboard de Grafana está diseñado para monitorear el servicio de cambio de monedas de arVault, incluyendo métricas de performance, negocio y recursos del sistema.

## Métricas Incluidas

### 1. Métricas de Performance (Artillery)

#### Scenarios Launched (RPS)
- **Descripción**: Número de escenarios de prueba ejecutados por segundo
- **Fuente**: Artillery StatsD plugin
- **Métrica**: `stats.gauges.$server.scenarioCounts.*`

#### Request Status Distribution
- **Descripción**: Distribución de estados de las requests (completadas, errores, pendientes, limitadas)
- **Fuente**: Artillery StatsD plugin
- **Métricas**:
  - `stats.gauges.$server.codes.200` - Requests completadas exitosamente
  - `stats.gauges.$server.errors.*` - Requests con errores
  - `stats.gauges.$server.pendingRequests` - Requests pendientes
  - `stats.gauges.$server.codes.429` - Requests limitadas (rate limiting)

#### Response Time (Client-side)
- **Descripción**: Tiempo de respuesta desde la perspectiva del cliente
- **Fuente**: Artillery StatsD plugin
- **Métricas**:
  - `stats.gauges.$server.scenarioDuration.p95` - Percentil 95
  - `stats.gauges.$server.scenarioDuration.median` - Mediana
  - `stats.gauges.$server.scenarioDuration.max` - Máximo

### 2. Métricas de Recursos del Sistema

#### System Resources
- **Descripción**: Uso de CPU y memoria del contenedor
- **Fuente**: cAdvisor + StatsD
- **Métricas**:
  - `stats.gauges.cadvisor.$container.cpu_cumulative_usage` - Uso de CPU
  - `stats.gauges.cadvisor.$container.memory_working_set` - Uso de memoria

### 3. Métricas de Negocio (Personalizadas)

#### Trading Volume by Currency
- **Descripción**: Volumen total operado por cada moneda (compras + ventas)
- **Fuente**: Aplicación arVault (custom metrics)
- **Métricas**: `stats.counters.$server.exchange.volume.{CURRENCY}`
- **Requerimiento**: Solicitado por el fundador de arVault

#### Net Position by Currency
- **Descripción**: Posición neta por moneda (compras suman, ventas restan)
- **Fuente**: Aplicación arVault (custom metrics)
- **Métricas**: `stats.gauges.$server.exchange.net.{CURRENCY}`
- **Requerimiento**: Solicitado por el fundador de arVault

#### Exchange Success Rate
- **Descripción**: Tasa de éxito de las operaciones de cambio
- **Fuente**: Aplicación arVault (custom metrics)
- **Métricas**:
  - `stats.counters.$server.exchange.successful` - Intercambios exitosos
  - `stats.counters.$server.exchange.failed` - Intercambios fallidos

#### Exchange Rates
- **Descripción**: Tasas de cambio actuales entre monedas
- **Fuente**: Aplicación arVault (custom metrics)
- **Métricas**: `stats.gauges.$server.exchange.rate.{FROM}_{TO}`

#### Exchange Operation Duration
- **Descripción**: Duración de las operaciones de cambio (server-side)
- **Fuente**: Aplicación arVault (custom metrics)
- **Métricas**: `stats.timers.$server.exchange.duration.*`

## Configuración

### Variables de Template
- **$server**: Nombre del servidor (artillery-exchange)
- **$container**: Nombre del contenedor (exchange-api-1, exchange-api-2, etc.)

### Refresh Rate
- **Dashboard**: 5 segundos
- **Paneles**: Actualización automática

### Time Range
- **Por defecto**: Últimos 5 minutos
- **Opciones**: 5m, 15m, 1h, 6h, 12h, 24h, 2d, 7d, 30d

## Instalación

1. Asegúrate de que todos los servicios estén ejecutándose:
   ```bash
   docker-compose up -d
   ```

2. Ejecuta el script de importación:
   ```bash
   ./perf/import-dashboard.sh
   ```

3. Accede a Grafana en http://localhost
   - Usuario: admin
   - Contraseña: admin

## Uso para Análisis de QA

Este dashboard permite analizar los siguientes atributos de calidad:

### Performance
- **Throughput**: Scenarios Launched (RPS)
- **Latency**: Response Time panels
- **Resource Utilization**: System Resources panel

### Reliability
- **Error Rate**: Request Status Distribution
- **Success Rate**: Exchange Success Rate panel

### Business Metrics
- **Volume Tracking**: Trading Volume by Currency
- **Position Management**: Net Position by Currency
- **Rate Monitoring**: Exchange Rates panel

### Scalability
- **Resource Usage**: System Resources panel
- **Load Handling**: Scenarios Launched vs Response Time correlation

## Notas Importantes

1. Las métricas personalizadas requieren que la aplicación esté configurada con StatsD
2. El dashboard asume que Artillery está configurado con el plugin StatsD
3. Las métricas de volumen y neto son acumulativas desde el inicio de la aplicación
4. Para pruebas de carga, ajusta los valores de carga según la capacidad de tu sistema
