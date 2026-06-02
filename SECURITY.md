| Version | Supported |
|---------|-----------|
| 3.x     | ✅ |
| 2.x     | ❌ |
| < 2.0   | ❌ |

## Reporting a Vulnerability

**Please DO NOT file a public issue.** 

Instead, send an email to **security@rct-engine.com** with:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours.

## Security Measures

### In Production
- ✅ TLS 1.3 for all endpoints
- ✅ FIDO2 MFA for admin access
- ✅ GPG encryption for backups
- ✅ SELinux mandatory access control
- ✅ Secrets in AWS Secrets Manager
- ✅ Regular security audits
- ✅ Automated dependency scanning
- ✅ Container image vulnerability scanning

### Data Protection
- Encryption at rest (AES-256)
- Encryption in transit (TLS 1.3)
- Database encryption enabled
- Redis AOF persistence encrypted
- Backups encrypted before storage

### Access Control
- Role-based access control (RBAC)
- API key rotation required every 90 days
- IP whitelisting available
- Audit logging for all actions
- Session timeout after 60 minutes

## Compliance

- **GDPR**: Data retention controls, right to deletion
- **SOC2**: Audit trails, access controls
- **HIPAA**: Available for BAA (enterprise only)

## Security Contacts

- **Emergency**: +1-650-123-4567 (24/7)
- **Email**: security@rct-engine.com
- **PGP Key**: [Download](https://rct-engine.com/security.asc)
