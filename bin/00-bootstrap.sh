#/bin/bash

export VAULT_TOKEN="vault-root-token"
export VAULT_ADDR="http://127.0.0.1:8200"

# use to name policies, app-role and others
export APP_NAME="intro"

function die () {
    echo "[ERROR] ${*}" 1>&2
    exit 1
}

function wait_for_vault () {
    max_attemtps=10
    attempts=0

    echo "# Waiting for Vault at '${VAULT_ADDR}'..."
    until curl --fail ${VAULT_ADDR} > /dev/null 2>&1 || [ $attempts -eq $max_attemtps ] ; do
        echo "## Failed to reach Vault at '${VAULT_ADDR}' (${attempts}/${max_attemtps})"
        sleep $(( attempts++ ))
    done

    if [ $attempts -eq $max_attemtps ]; then
        die "Can't reach Vault at '${VAULT_ADDR}', timeout!"
    fi
}

function enable_secrets_kv () {
    echo "# Enabling KV mount..."
    if ! vault read sys/mounts |grep -q '^secret/.*version:2' ; then
        vault secrets enable -version=2 kv || \
            die "Can't enable secrets kv!"
    fi
}

function write_policy() {
    echo "# Writing '${APP_NAME}' policy..."
    vault policy write ${APP_NAME} policy.hcl || \
        die "Can't apply '${APP_NAME}' policy!"
}

wait_for_vault
enable_secrets_kv
write_policy

echo "# Writing '.env' file with Vault variables..."
cat <<EOS > .env && cat .env
export APP_NAME="${APP_NAME}"
export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_TOKEN="${VAULT_TOKEN}"
EOS
