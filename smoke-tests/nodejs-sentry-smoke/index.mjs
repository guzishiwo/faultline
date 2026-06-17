import * as Sentry from "@sentry/node";

const rawDsn = process.env.FAULTLINE_DSN;
const dsn = rawDsn?.trim();

if (!dsn) {
  console.error("Missing FAULTLINE_DSN. Set it to a Faultline project DSN and run again.");
  process.exit(1);
}

if (rawDsn !== dsn) {
  console.warn("Trimmed surrounding whitespace from FAULTLINE_DSN.");
}

const dsnError = validateFaultlineDsn(dsn);

if (dsnError) {
  console.error(`Invalid FAULTLINE_DSN: ${dsnError}`);
  process.exit(1);
}

Sentry.init({
  dsn,
  environment: process.env.FAULTLINE_ENVIRONMENT ?? "nodejs-smoke",
  release: process.env.FAULTLINE_RELEASE ?? "nodejs-sentry-smoke@0.1.0",
  tracesSampleRate: 0
});

if (!Sentry.getClient()) {
  console.error("Sentry did not initialize. Check that FAULTLINE_DSN is a valid Sentry DSN.");
  process.exit(1);
}

Sentry.captureException(new Error("Real SDK smoke exception"));

const flushed = await Sentry.flush(2000);

console.log(
  flushed
    ? "Captured and flushed Real SDK smoke exception."
    : "Timed out while flushing Real SDK smoke exception."
);

function validateFaultlineDsn(value) {
  let url;

  try {
    url = new URL(value);
  } catch {
    return "expected a URL like http://PUBLIC_KEY:SECRET_KEY@localhost:4000/PROJECT_ID";
  }

  if (!["http:", "https:"].includes(url.protocol)) {
    return "protocol must be http or https";
  }

  if (!/^[a-f0-9]{32}$/.test(url.username)) {
    return "public key must be 32 lowercase hex characters; recreate the Faultline project if it was generated before the hex-key fix";
  }

  if (url.password && !/^[a-f0-9]{32}$/.test(url.password)) {
    return "secret key must be 32 lowercase hex characters; recreate the Faultline project if it was generated before the hex-key fix";
  }

  if (!/^\/[^/]+$/.test(url.pathname)) {
    return "path must contain a single project id, for example /3";
  }

  return null;
}
