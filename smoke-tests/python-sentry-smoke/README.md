# Python Sentry SDK smoke demo

This demo sends a real exception through `sentry-sdk` to Faultline.

## Run

Start Faultline first:

```sh
mix phx.server
```

Then run this demo in another terminal. The demo depends on [uv](https://docs.astral.sh/uv/) — `uv run` will create a local venv, install `sentry-sdk` from `requirements.txt`, and execute the script:

```sh
cd demos/python-sentry-smoke
FAULTLINE_DSN="http://PUBLIC_KEY:SECRET_KEY@localhost:4000/PROJECT_ID" uv run --with-requirements requirements.txt smoke.py
```

If you prefer to manage the venv yourself, the equivalent steps are:

```sh
cd demos/python-sentry-smoke
uv venv
uv pip install -r requirements.txt
source .venv/bin/activate
FAULTLINE_DSN="http://PUBLIC_KEY:SECRET_KEY@localhost:4000/PROJECT_ID" python smoke.py
```

Use the DSN shown by Faultline for the project you want to test. The SDK will send
the event to Faultline's Sentry-compatible envelope endpoint.

If the demo reports that the public or secret key is not lowercase hex, recreate
the Faultline project so it gets SDK-compatible keys.

## Expected result

The command should print:

```text
Captured and flushed Real SDK smoke exception.
```

Faultline should receive an exception named:

```text
Real SDK smoke exception
```

Optional environment variables:

```sh
FAULTLINE_ENVIRONMENT=python-smoke
FAULTLINE_RELEASE=python-sentry-smoke@0.1.0
FAULTLINE_DEBUG=1   # log the SDK's transport errors to stderr
```

## Troubleshooting

If the demo times out flushing, the SDK could not reach Faultline in 5 s.
Check, in order:

1. **Faultline is up.** From the project root run `mix phx.server` and confirm
   `http://localhost:4000` responds.
2. **The project id exists.** The DSN path (`/2` in the example) is the Faultline
   project number; a missing project returns 404 and the SDK drops the event.
3. **Reproduce the underlying error.** Re-run with `FAULTLINE_DEBUG=1` and the
   SDK's `urllib3`/`requests` traceback (connection refused, TLS error, 4xx/5xx)
   will be printed to stderr.
