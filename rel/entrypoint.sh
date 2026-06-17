#!/bin/sh
set -eu

mkdir -p /data

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  if [ ! -f /data/secret_key_base ]; then
    /app/bin/faultline eval 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(64)))' > /data/secret_key_base
    chmod 600 /data/secret_key_base
  fi

  export SECRET_KEY_BASE="$(cat /data/secret_key_base)"
fi

/app/bin/faultline eval 'Faultline.Release.migrate()'
/app/bin/faultline eval 'Faultline.Release.bootstrap_admin_from_env()'

exec /app/bin/faultline start
