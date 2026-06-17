"""Faultline Python Sentry SDK smoke demo.

Sends a real exception through ``sentry-sdk`` to Faultline.
"""

from __future__ import annotations

import logging
import os
import re
import sys
import time
from urllib.parse import urlparse

import sentry_sdk
from sentry_sdk.transport import HttpTransport


class RecordingHttpTransport(HttpTransport):
    """HTTP transport that keeps enough state for a synchronous smoke result."""

    def __init__(self, options):
        super().__init__(options)
        self.status_codes = []
        self.response_errors = []
        self.transport_errors = []

    def _send_request(self, body, headers, endpoint_type, envelope=None):
        self._update_headers(headers)

        try:
            response = self._request("POST", endpoint_type, body, headers)
        except Exception as exc:
            self.transport_errors.append(str(exc))
            self._handle_request_error(envelope=envelope, loss_reason="network")
            raise

        try:
            self.status_codes.append(response.status)

            if response.status < 200 or response.status >= 300:
                response_body = getattr(response, "data", getattr(response, "content", None))
                self.response_errors.append(f"HTTP {response.status}: {response_body!r}")

            self._handle_response(response=response, envelope=envelope)
        finally:
            response.close()


def main() -> int:
    raw_dsn = os.environ.get("FAULTLINE_DSN")
    dsn = raw_dsn.strip() if raw_dsn else None

    if not dsn:
        print(
            "Missing FAULTLINE_DSN. Set it to a Faultline project DSN and run again.",
            file=sys.stderr,
        )
        return 1

    if raw_dsn != dsn:
        print("Trimmed surrounding whitespace from FAULTLINE_DSN.")

    dsn_error = validate_faultline_dsn(dsn)
    if dsn_error:
        print(f"Invalid FAULTLINE_DSN: {dsn_error}", file=sys.stderr)
        return 1

    # Surface SDK transport errors (refused connections, 4xx/5xx, ...) to stderr
    # so a flush timeout is diagnosable instead of silent.
    logging.basicConfig(level=logging.DEBUG, format="sentry-sdk: %(message)s")

    sentry_sdk.init(
        dsn=dsn,
        environment=os.environ.get("FAULTLINE_ENVIRONMENT", "python-smoke"),
        release=os.environ.get("FAULTLINE_RELEASE", "python-sentry-smoke@0.1.0"),
        traces_sample_rate=0,
        debug=os.environ.get("FAULTLINE_DEBUG") == "1",
        transport=RecordingHttpTransport,
    )

    client = sentry_sdk.get_client()
    if client.is_active() is False:
        print(
            "Sentry did not initialize. Check that FAULTLINE_DSN is a valid Sentry DSN.",
            file=sys.stderr,
        )
        return 1

    try:
        raise RuntimeError("Real SDK smoke exception")
    except RuntimeError:
        sentry_sdk.capture_exception()

    # Flush the queue so the demo can report success synchronously.
    sentry_sdk.flush(timeout=5.0)
    # Tiny grace period to give the worker thread a chance to drain the last item.
    time.sleep(0.05)

    if transport_succeeded(client.transport):
        print("Captured and flushed Real SDK smoke exception.")
        return 0

    print(
        "Failed to flush Real SDK smoke exception.\n"
        f"{transport_failure_detail(client.transport)}\n"
        "  - Is Faultline running? Try `curl -sS -o /dev/null -w '%{http_code}\\n' "
        f"{envelope_probe_url(dsn)}` and confirm the server is up.\n"
        "  - Does the project id in the DSN exist in Faultline? "
        "A 404 means the path matches a project number that has no row.\n"
        "  - Re-run with FAULTLINE_DEBUG=1 to log the underlying SDK error.",
        file=sys.stderr,
    )
    return 1


def transport_succeeded(transport) -> bool:
    status_codes = getattr(transport, "status_codes", [])
    transport_errors = getattr(transport, "transport_errors", [])

    return (
        bool(status_codes)
        and not transport_errors
        and all(200 <= status_code < 300 for status_code in status_codes)
    )


def transport_failure_detail(transport) -> str:
    status_codes = getattr(transport, "status_codes", [])
    response_errors = getattr(transport, "response_errors", [])
    transport_errors = getattr(transport, "transport_errors", [])

    if transport_errors:
        return "  - Transport error: " + "; ".join(transport_errors)

    if response_errors:
        return "  - Faultline rejected the event: " + "; ".join(response_errors)

    if status_codes:
        statuses = ", ".join(str(status_code) for status_code in status_codes)
        return f"  - Faultline returned unexpected HTTP status code(s): {statuses}"

    return "  - No HTTP response was recorded before the flush timeout."


def envelope_probe_url(dsn: str) -> str:
    """Build the URL the SDK will POST to, for the diagnostic hint."""
    url = urlparse(dsn)
    path = (url.path or "").rstrip("/")
    return f"{url.scheme}://{url.hostname}:{url.port or 80}{path}/envelope/"


def validate_faultline_dsn(value: str) -> str | None:
    try:
        url = urlparse(value)
    except ValueError:
        return "expected a URL like http://PUBLIC_KEY:SECRET_KEY@localhost:4000/PROJECT_ID"

    if url.scheme not in ("http", "https"):
        return "scheme must be http or https"

    if not re.fullmatch(r"[a-f0-9]{32}", url.username or ""):
        return (
            "public key must be 32 lowercase hex characters; "
            "recreate the Faultline project if it was generated before the hex-key fix"
        )

    if url.password and not re.fullmatch(r"[a-f0-9]{32}", url.password):
        return (
            "secret key must be 32 lowercase hex characters; "
            "recreate the Faultline project if it was generated before the hex-key fix"
        )

    path = url.path or ""
    if not re.fullmatch(r"/[^/]+", path):
        return "path must contain a single project id, for example /3"

    return None


if __name__ == "__main__":
    sys.exit(main())
