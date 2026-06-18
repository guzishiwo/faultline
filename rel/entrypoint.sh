#!/bin/sh
set -eu

data_dir="${FAULTLINE_VOLUME_MOUNT_PATH:-/data}"

if [ -z "${DATABASE_PATH:-}" ]; then
  export DATABASE_PATH="${data_dir%/}/faultline.db"
fi

database_dir="$(dirname "$DATABASE_PATH")"
mkdir -p "$database_dir"

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  secret_key_base_path="${data_dir%/}/secret_key_base"
  mkdir -p "$(dirname "$secret_key_base_path")"

  if [ ! -f "$secret_key_base_path" ]; then
    openssl rand -base64 64 > "$secret_key_base_path"
    chmod 600 "$secret_key_base_path"
  fi

  export SECRET_KEY_BASE="$(cat "$secret_key_base_path")"
fi

/app/bin/faultline eval 'Faultline.Release.migrate()'
/app/bin/faultline eval 'Faultline.Release.bootstrap_admin_from_env()'

exec /app/bin/faultline start
