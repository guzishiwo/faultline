# Node.js Sentry SDK smoke demo

This demo sends a real exception through `@sentry/node` to Faultline.

## Run

Start Faultline first:

```sh
mix phx.server
```

Then run this demo in another terminal:

```sh
cd demos/nodejs-sentry-smoke
pnpm install
FAULTLINE_DSN="http://PUBLIC_KEY:SECRET_KEY@localhost:4000/PROJECT_ID" pnpm smoke
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
FAULTLINE_ENVIRONMENT=nodejs-smoke
FAULTLINE_RELEASE=nodejs-sentry-smoke@0.1.0
```
