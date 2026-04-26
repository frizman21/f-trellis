#!/bin/bash
# Creates the Solid Cache / Queue / Cable databases on first boot.
# Runs once when the postgres data volume is empty.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
  CREATE DATABASE app_production_cache OWNER ${POSTGRES_USER};
  CREATE DATABASE app_production_queue OWNER ${POSTGRES_USER};
  CREATE DATABASE app_production_cable OWNER ${POSTGRES_USER};
EOSQL
