FROM elixir:1.18.4-otp-27-slim AS build

RUN apt-get update -y && apt-get install -y --no-install-recommends \
  build-essential ca-certificates git nodejs npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY assets/package*.json assets/
RUN npm ci --prefix assets --omit=dev

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
  PORT=4010

COPY --from=build /app/_build/prod/rel/faultline ./
COPY rel/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 4010

ENTRYPOINT ["/entrypoint.sh"]
