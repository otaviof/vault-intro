# `vault-intro`

A repository to show examples of use-cases covered by [HashiCorp Vault][vault]. For those, the
following tools are employed:

- [Docker-Compose][dockercompose];
- [HashiCorp Vault][vault];
- [PGCLI][pgcli];

Make sure all of them are available before starting playing with the examples in this repository.

## Vault Examples

Before you start, make sure Vault and PostgreSQL are up and running, by:

``` bash
docker-compose up
```

And then you can already run the boostrap script:

``` bash
./bin/00-bootstrap.sh
```

Which will enable [Secrets KV Store `v2`][vaultkv] and apply the [policy file](./policy.hcl). Those
are the basic steps to start using Vault. And please note, KV-Store might not be used in all
use-cases, but since it can be considered a "base feature" it's worth having it enabled from start.

The [bootstrap](./bin/00-bootstrap.sh) script will provide a `.env` file, which contains `VAULT_ADDR`
and `VAULT_TOKEN`.

### Token Based

In order to communicate with Vault, you need to obtain a [token][vaulttoken], and the simplest
way, would be in the case you already have one issued. There are tokens to grant "root access" to
Vault, you will need to use those on enabling/disabling features, and other system administration
tasks, however, it's encouraged to issue tokens with fine grain access, so you can have a better
grip on each user/app is able to do. Please consider [official documentation][vaultpolicies] to
understand more about policies in Vault.

To load the tokens issued before, run:

``` bash
source .env
```

And then you will be able to write a key-value pair in Vault, for instance:

```
$ vault kv put secret/test key=value
Key              Value
---              -----
created_time     2019-07-19T07:29:56.0225265Z
deletion_time    n/a
destroyed        false
version          1
```

For instance, to read `key` back, you would execute:

```
$ vault kv get secret/test
====== Metadata ======
Key              Value
---              -----
created_time     2019-07-19T07:29:56.0225265Z
deletion_time    n/a
destroyed        false
version          1

=== Data ===
Key    Value
---    -----
key    value
```

#### Issuing Tokens

A token needs to be bind to a policy, the policy control the authorization process, granting or
denying access to data or actions that can be done against Vault.

```
$ vault token create -policy=intro -period=120s
Key                Value
---                -----
token              s.ZVjo3gQIEPEVsluMnhpNrwJY
token_accessor     WrIza9hkte9aLnjJzUHvGRsg
token_duration     2m
token_renewable    true
token_policies     [default intro]
```

And to revoke:

```
$ vault token revoke s.ZVjo3gQIEPEVsluMnhpNrwJY
Success! Revoked token (if it existed)
```

Would be a good practice to have a single token per application (per environment), and as you
notice, those tokens will have a expiration period, therefore, you would need to re-issue tokens
from time to time, or renew.

### AppRole

Vault also ships with AppRole authentication. The objective of this method is to identify machines or
applications individually, therefore you issue a pair of identifiers that in combination, can issue a
token, which is bounded to the policy and expiration period directives configured for that specific
`approle` application.

Please consider [`01-approle.sh`](./bin/01-approle.sh) script. It automates the commands to enable
AppRole authentication and issue one pair of [role-id and secret-id][vaultapprolecred], that we
can use to test authentication

Run the script:

``` bash
./bin/01-approle.sh
```

Then load new environment variables:

``` bash
source .env
```

And then you will be able to issue a token, based on role-id and secret-id:

``` bash
vault write auth/approle/login role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}"
```

For instance:

```
$ vault write auth/approle/login role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}"
Key                     Value
---                     -----
token                   s.6D3vmLPypX1hbMhf8zFsuOct
token_accessor          KRfB5FP8jyGddn5grvBARrM7`
token_duration          3m
token_renewable         true
token_policies          [default intro]
token_meta_role_name    intro
```

And then we can employ the new token to read data from Vault:

```
$ VAULT_TOKEN="s.6D3vmLPypX1hbMhf8zFsuOct" vault kv get secret/test
====== Metadata ======
Key              Value
---              -----
created_time     2019-07-19T08:37:59.2103535Z
deletion_time    n/a
destroyed        false
version          2

=== Data ===
Key    Value
---    -----
key    value
```

### Database

Vault has third party integration with other systems, like databases. You can instruct Vault to
connect to your database and setup username and password on your behalf, therefore Vault is able to
on-the-fly create a new username/password.

Please consider [`02-database.sh`](./bin/02-database.sh), and execute the script to configure a
PostgreSQL connection:

```
./bin/02-database.sh
```

Afterwards, we are able to issue new database credentials by:

``` bash
vault read database/creds/${APP_NAME}
```

For instance:

```
$ vault read database/creds/${APP_NAME}
Key                Value
---                -----
lease_id           database/creds/intro/R1Z2S66IOH6MA9NLRSlrTZJw
lease_duration     1h
lease_renewable    true
password           A1a-YUuBm3x22H5hCVKC
username           v-token-intro-D7dCgYF09qgh8PD7NyDf-1563530392
```

With `username` and `password` we can connect to the database:

``` bash
pgcli --host 127.0.0.1 --username v-token-intro-D7dCgYF09qgh8PD7NyDf-1563530392 --dbname postgres
```

## Retrieving Secrets

In order to automate the process of Vault authentication and data retrieval, we have a number of
tooling to consider. Most of them are employed as a `init-container` in Kubernetes, so they would run
before the actual application to download sensitive data, and the application would then read from a
shared location.

So please consider the following links:

- https://github.com/UKHomeOffice/vault-sidekick
- https://github.com/otaviof/vault-handler

[vault]: https://www.vaultproject.io
[pgcli]: https://pgcli.com/
[dockercompose]: https://docs.docker.com/compose
[vaultkv]: https://www.vaultproject.io/docs/secrets/kv/kv-v2.html
[vaultpolicies]: https://www.vaultproject.io/docs/concepts/policies.html
[vaulttoken]: https://www.vaultproject.io/docs/auth/token.html
[vaultapprole]: https://www.vaultproject.io/docs/auth/approle.html
[vaultapprolecred]: https://www.vaultproject.io/docs/auth/approle.html#credentials-constraints