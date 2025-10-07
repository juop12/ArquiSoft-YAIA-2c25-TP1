.PHONY: up down restart build logs test

COMPOSE_FILE := docker-compose.yml
APP_URL := http://localhost:5555
GRAFANA_URL := http://localhost:80
GRAPHITE_URL := http://localhost:8090
CADVISOR_URL := http://localhost:8080

__WORKFLOW__:
up:
	docker-compose up -d --build
	@echo "System up!"
	@echo "API: $(APP_URL)"
	@echo "Grafana: $(GRAFANA_URL)"
	@echo "Graphite: $(GRAPHITE_URL)"
	@echo "cAdvisor: $(CADVISOR_URL)"
	@echo ""

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
