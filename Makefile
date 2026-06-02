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



# Add to existing Makefile

.PHONY: validate seed cultural-update benchmark rotate-keys

# Validation and testing
validate:
	./scripts/validate_deployment.sh

seed:
	./scripts/seed_database.sh

cultural-update:
	./scripts/update_cultural_data.sh $(FILE)

benchmark:
	./scripts/performance_benchmark.sh $(URL) $(API_KEY) $(REQUESTS) $(CONCURRENCY)

rotate-keys:
	./scripts/rotate_api_keys.sh

# Production operations
prod-status:
	kubectl get pods -n rct-engine
	kubectl get svc -n rct-engine
	kubectl get ingress -n rct-engine

prod-logs-api:
	kubectl logs -f deployment/rct-api -n rct-engine

prod-logs-worker:
	kubectl logs -f deployment/rct-worker -n rct-engine

prod-scale-up:
	kubectl scale deployment rct-api -n rct-engine --replicas=10

prod-scale-down:
	kubectl scale deployment rct-api -n rct-engine --replicas=3

prod-restart:
	kubectl rollout restart deployment/rct-api -n rct-engine
	kubectl rollout restart deployment/rct-worker -n rct-engine

# Database operations
db-backup:
	./scripts/backup_all.sh

db-restore:
	./scripts/restore_all.sh

db-cleanup:
	./scripts/cleanup_old_data.sh $(DAYS)

db-stats:
	docker exec rct-postgres psql -U rct_admin -d rct_saas -c "\
		SELECT \
			(SELECT COUNT(*) FROM users) as users, \
			(SELECT COUNT(*) FROM organizations) as orgs, \
			(SELECT COUNT(*) FROM translation_audit_logs) as translations, \
			(SELECT COUNT(*) FROM cultural_context_matrix) as cultural_entries;"

# Security
security-scan:
	trivy fs --severity HIGH,CRITICAL --exit-code 1 .
	bandit -r backend/ -ll
	safety check -r backend/requirements.txt

security-audit:
	./security/gpg/verify_backups.sh
	./security/fido2/test_webauthn.sh

# Monitoring
monitoring-start:
	docker-compose -f monitoring/docker-compose.monitoring.yml up -d

monitoring-stop:
	docker-compose -f monitoring/docker-compose.monitoring.yml down

monitoring-logs:
	docker-compose -f monitoring/docker-compose.monitoring.yml logs -f

grafana-password:
	kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
