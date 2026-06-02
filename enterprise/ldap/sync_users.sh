#!/bin/bash
# LDAP User Sync Script for RCT-Engine

LDAP_HOST="ldap://localhost:389"
LDAP_BASE_DN="dc=rct-engine,dc=com"
LDAP_BIND_DN="cn=admin,dc=rct-engine,dc=com"
LDAP_BIND_PASSWORD="${LDAP_ADMIN_PASSWORD}"

echo "🔄 Syncing LDAP users to RCT-Engine..."

# Search for users in LDAP
ldapsearch -x -H "$LDAP_HOST" \
    -D "$LDAP_BIND_DN" \
    -w "$LDAP_BIND_PASSWORD" \
    -b "$LDAP_BASE_DN" \
    "objectClass=inetOrgPerson" \
    uid mail givenName sn | while read line; do
    
    # Parse LDIF output
    if [[ $line == uid:* ]]; then
        USERNAME=$(echo $line | cut -d' ' -f2)
    elif [[ $line == mail:* ]]; then
        EMAIL=$(echo $line | cut -d' ' -f2)
    elif [[ $line == givenName:* ]]; then
        FIRST_NAME=$(echo $line | cut -d' ' -f2-)
    elif [[ $line == sn:* ]]; then
        LAST_NAME=$(echo $line | cut -d' ' -f2-)
        
        # Create or update user in RCT-Engine
        curl -X POST "https://api.rct-engine.com/api/v1/admin/users/sync" \
            -H "X-Admin-Token: ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"username\": \"$USERNAME\",
                \"email\": \"$EMAIL\",
                \"firstName\": \"$FIRST_NAME\",
                \"lastName\": \"$LAST_NAME\",
                \"source\": \"ldap\"
            }"
        
        echo "  ✓ Synced: $USERNAME ($EMAIL)"
    fi
done

echo "✅ LDAP sync completed"
