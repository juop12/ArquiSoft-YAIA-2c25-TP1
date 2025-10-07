.PHONY: help up down restart build logs test

COMPOSE_FILE := docker-compose.yml
APP_URL := http://localhost:5555
GRAFANA_URL := http://localhost:80
GRAPHITE_URL := http://localhost:8090
CADVISOR_URL := http://localhost:8080

help:
	@echo "ArVault Exchange System - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

__WORKFLOW__:
up:
	docker-compose up -d --build
	@echo "System up!"
	@echo "API: $(APP_URL)"
	@echo "Grafana: $(GRAFANA_URL)"
	@echo "Graphite: $(GRAPHITE_URL)"
	@echo "cAdvisor: $(CADVISOR_URL)"
	@echo ""

setup-dashboard: ## Updates the datasource UID in the Grafana dashboard
	@./scripts/update-dashboard-datasource.sh

import-dashboard: ## Imports the updated dashboard to Grafana automatically
	@./scripts/import-dashboard.sh

full-setup: up setup-dashboard import-dashboard ## Deploys the entire system and configures Grafana automatically
	@echo "System fully configured."

down:
	@echo "Stopping all services..."
	docker-compose down
	@echo "System down!"

restart:
	@echo "Restarting system..."
	docker-compose restart
	@echo "System restarted!"

build:
	@echo "Rebuilding application..."
	docker-compose build --no-cache api
	@echo "Build completed!"

logs:
	docker-compose logs -f

__TESTING__:

test:
	@echo "Executing load tests..."
	cd perf && npm install && npm run api

test-rates:
	@echo "Testing endpoint /rates..."
	cd perf && npm run api

test-baseline:
	@echo "Running baseline performance test..."
	cd perf && npm run baseline

test-stress:
	@echo "Running stress test..."
	cd perf && npm run stress

test-exchange:
	@echo "Running exchange operations test..."
	cd perf && npm run exchange

test-burst:
	@echo "Running burst traffic test..."
	cd perf && npm run burst
