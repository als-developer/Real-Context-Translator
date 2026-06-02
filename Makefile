# RCT-Engine Ultimate Makefile
.PHONY: help build test run deploy clean lint format migrate

help:
	@echo "RCT-Engine Ultimate Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build         - Build all components"
	@echo "  test          - Run all tests"
	@echo "  run           - Run development server"
	@echo "  deploy        - Deploy to production"
	@echo "  clean         - Clean build artifacts"
	@echo "  lint          - Run linters"
	@echo "  format        - Format code"
	@echo "  migrate       - Run database migrations"
	@echo "  backup        - Create backup"
	@echo "  restore       - Restore from backup"
	@echo "  monitor       - Start monitoring"
	@echo "  health        - Check health status"

build:
	./scripts/build_all.sh

test:
	./scripts/test_all.sh

run:
	docker-compose -f infrastructure/docker/docker-compose.yml up -d
	docker-compose -f monitoring/docker-compose.monitoring.yml up -d
	@echo "Services started:"
	@echo "  API: http://localhost:8000"
	@echo "  Grafana: http://localhost:3000"
	@echo "  Prometheus: http://localhost:9090"

deploy:
	./scripts/deploy_prod.sh

clean:
	rm -rf build/
	rm -rf frontend/web/dist/
	rm -rf frontend/web/node_modules/
	rm -rf backend/__pycache__/
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	docker system prune -f

lint:
	black backend/ --check
	isort backend/ --check-only
	flake8 backend/
	mypy backend/

format:
	black backend/
	isort backend/

migrate:
	alembic upgrade head

migrate-down:
	alembic downgrade -1

backup:
	./scripts/backup_all.sh

restore:
	./scripts/restore_all.sh

monitor:
	./scripts/monitor_rct.sh

health:
	./scripts/health_check.sh

seed:
	docker exec -i rct-postgres psql -U rct_admin -d rct_saas < database/seeds/countries.sql
	docker exec -i rct-postgres psql -U rct_admin -d rct_saas < database/seeds/slangs.sql

logs-api:
	docker-compose -f infrastructure/docker/docker-compose.yml logs -f api

logs-worker:
	docker-compose -f infrastructure/docker/docker-compose.yml logs -f worker

shell-api:
	docker exec -it rct-api bash

shell-db:
	docker exec -it rct-postgres psql -U rct_admin -d rct_saas

redis-cli:
	docker exec -it rct-redis redis-cli

status:
	docker-compose -f infrastructure/docker/docker-compose.yml ps
	@echo ""
	./scripts/health_check.sh
