#!/bin/bash

function die () {
    echo "[ERROR] ${*}" 1>&2
    exit 1
}

source .env || die "Can't find '.env'!"

function enable_approle () {
    echo "# Enabling approle authentication type..."
    if ! vault auth list |grep -q approle ; then
        vault auth enable approle || \
            die "Can't enable approle!"
    fi
}

function create_approle_app () {
    echo "# Creating approle role '${APP_NAME}'..."
    vault write auth/approle/role/${APP_NAME} \
        policies=${APP_NAME} \
        secret_id_num_uses=0 \
        secret_id_ttl=0 \
        token_max_ttl=3m \
        token_num_uses=0 \
        token_ttl=3m || \
            die "Can't create '${APP_NAME}' approle!"
}

function get_role_id () {
    vault read auth/approle/role/${APP_NAME}/role-id \
        |grep role_id \
        |awk '{print $2}'
}

function get_secret_id () {
    vault write -f auth/approle/role/${APP_NAME}/secret-id \
        |grep secret_id \
        |grep -v accessor \
        |awk '{print $2}'
}

function register_app () {
    echo "# Registering application based on secret-id and role-id..."

    local role_id=$1
    local secret_id=$2

    vault write auth/approle/login \
        role_id=${role_id} \
        secret_id=${secret_id} || \
            die "Can't register role-id and secret-id for login!"
}

enable_approle
create_approle_app

ROLE_ID="$(get_role_id)"
[ -z $ROLE_ID ] && \
    die "Can't obtain app-role role-id for '${APP_NAME}'!"

SECRET_ID="$(get_secret_id)"
[ -z $SECRET_ID ] && \
    die "Can't obtain app-role secret-id for '${APP_NAME}'!"

register_app "${ROLE_ID}" "${SECRET_ID}"

echo "# Writing '.env' file with Vault variables..."

# cleaning up before writing
grep -E -v "(VAULT_ROLE_ID|VAULT_SECRET_ID)" .env > .env.new
mv .env.new .env > /dev/null || die "Can't rename '.env' file!"

# writing role and secret-id
cat <<EOS >> .env && cat .env
export VAULT_ROLE_ID="${ROLE_ID}"
export VAULT_SECRET_ID="${SECRET_ID}"
EOS
