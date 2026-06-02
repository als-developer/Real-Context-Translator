# Changelog

## [3.0.0] - 2026-06-01

### Added
- AVX-512 hardware acceleration for risk detection
- Go billing exporter with 100k req/sec throughput
- FIDO2 WebAuthn multi-factor authentication
- Complete Terraform infrastructure for AWS
- Kubernetes deployment manifests with HPA
- Prometheus recording rules and SLO alerts
- 50+ new cultural context entries
- Batch translation API with webhook support

### Changed
- Upgraded FastAPI to 0.110+
- Migrated to Pydantic v2
- Improved rate limiting with token bucket
- Redis cache TTL optimized (50% hit rate increase)

### Fixed
- Connection pool exhaustion in high-load scenarios
- Stripe webhook signature validation
- Memory leak in C++ lock-free queue
- Race condition in organization quota check

### Security
- Added SELinux policies for all containers
- GPG encryption for all backups
- Secrets now stored in AWS Secrets Manager
- Regular security scans in CI/CD

## [2.5.0] - 2026-03-15

### Added
- Multi-language support (10 new languages)
- Dashboard analytics with charts
- Slack alert integration

### Fixed
- Database migration issues
- Rate limiting edge cases

## [2.0.0] - 2025-12-01

### Added
- Initial SaaS release
- Cultural context AI
- Stripe billing integration
- PostgreSQL + Redis backend
