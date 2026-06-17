FROM hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20250610-slim AS build

RUN apt-get update -y && apt-get install -y --no-install-recommends \
  build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM debian:bookworm-20250610-slim AS app

RUN apt-get update -y && apt-get install -y --no-install-recommends \
  ca-certificates libstdc++6 openssl ncurses-bin \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV HOME=/app \
  MIX_ENV=prod \
  PHX_SERVER=true \
  DATABASE_PATH=/data/faultline.db \
  PORT=4010

COPY --from=build /app/_build/prod/rel/faultline ./
COPY rel/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 4010

ENTRYPOINT ["/entrypoint.sh"]
