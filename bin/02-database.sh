#/bin/bash

set -x

function die () {
    echo "[ERROR] ${*}" 1>&2
    exit 1
}

source .env || die "Can't find '.env'!"

function enable_database () {
    echo "# Enabling database..."
    if ! vault read sys/mounts |grep -q '^database/' ; then
        vault secrets enable database || \
            die "Can't enable 'database' secret type!"
    fi
}

function configure_plugin () {
    echo "# Configuring PosgreSQL database plugin..."
    vault write database/config/${APP_NAME} \
        plugin_name=postgresql-database-plugin \
        allowed_roles="${APP_NAME}" \
        connection_url='postgresql://{{username}}:{{password}}@postgresql:5432/postgres?sslmode=disable' \
        username="postgres" \
        password="1" || \
            die "Can't configure PostgreSQL database plugin!"
}

function map_role () {
    echo "# Mapping a role with creation statement..."
    vault write database/roles/${APP_NAME} \
        db_name="${APP_NAME}" \
        creation_statements="$(cat <<EOS
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
EOS
)" \
        default_ttl="1h" \
        max_ttl="24h"
}

enable_database
configure_plugin
map_role