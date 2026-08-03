#!/usr/bin/env python3
"""Upload a signed Android App Bundle to Google Play (Android Publisher API v3).

Creates an edit, uploads the AAB, assigns it to a track, and commits the edit.
Defaults (overridable via env / CLI): package ai.enjoy.player, track alpha,
release status draft.

Large AABs (~180MB with native libs) use resumable chunked upload with a long
HTTP timeout and retry on transient socket timeouts.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import time
from pathlib import Path

import httplib2
from google.oauth2 import service_account
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPES = ("https://www.googleapis.com/auth/androidpublisher",)
DEFAULT_PACKAGE = "ai.enjoy.player"
DEFAULT_TRACK = "alpha"
DEFAULT_STATUS = "draft"
# 8 MiB chunks recover faster on flaky links than the library default (~100 MiB).
DEFAULT_CHUNK_SIZE = 8 * 1024 * 1024
DEFAULT_TIMEOUT_SEC = 600
DEFAULT_CHUNK_RETRIES = 12


def _resolve_credentials_path(explicit_path: str | None) -> Path:
    if explicit_path:
        path = Path(explicit_path).expanduser()
        if not path.is_file():
            raise SystemExit(f"Service account JSON not found: {path}")
        return path

    env_path = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH", "").strip()
    if env_path:
        path = Path(env_path).expanduser()
        if not path.is_file():
            raise SystemExit(f"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH not found: {path}")
        return path

    # Prefer base64 in CI — raw JSON secrets corrupt private_key newlines in GHA env.
    b64 = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64", "").strip()
    if b64:
        import base64

        try:
            raw_bytes = base64.b64decode(b64, validate=False)
            raw = raw_bytes.decode("utf-8")
            json.loads(raw)
        except Exception as exc:  # noqa: BLE001 — surface decode/parse clearly
            raise SystemExit(
                f"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 is not valid base64 JSON: {exc}"
            ) from exc
        fd, tmp_name = tempfile.mkstemp(prefix="play-sa-", suffix=".json")
        os.close(fd)
        tmp = Path(tmp_name)
        tmp.write_bytes(raw_bytes)
        os.chmod(tmp, 0o600)
        return tmp

    raw = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        raise SystemExit(
            "Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH, "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64, or "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
        )

    # GitHub secrets sometimes store literal "\n" sequences.
    raw = raw.replace("\\r\\n", "\n").replace("\\n", "\n")
    if raw.startswith('"') and raw.endswith('"'):
        raw = raw[1:-1]
    try:
        json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not valid JSON: {exc}\n"
            "In GitHub Actions prefer GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 "
            "(base64 -w0 .google/play-service-account.json)."
        ) from exc

    fd, tmp_name = tempfile.mkstemp(prefix="play-sa-", suffix=".json")
    os.close(fd)
    tmp = Path(tmp_name)
    tmp.write_text(raw, encoding="utf-8")
    os.chmod(tmp, 0o600)
    return tmp


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise SystemExit(f"{name} must be an integer, got {raw!r}") from exc


def _upload_bundle_resumable(service, *, package_name: str, edit_id: str, aab: Path) -> dict:
    size_mb = aab.stat().st_size / (1024 * 1024)
    chunk_size = _env_int("GOOGLE_PLAY_UPLOAD_CHUNK_BYTES", DEFAULT_CHUNK_SIZE)
    max_retries = _env_int("GOOGLE_PLAY_UPLOAD_CHUNK_RETRIES", DEFAULT_CHUNK_RETRIES)
    print(f"Uploading AAB ({size_mb:.1f} MiB) in {chunk_size // (1024 * 1024)} MiB chunks...")

    media = MediaFileUpload(
        str(aab),
        mimetype="application/octet-stream",
        resumable=True,
        chunksize=chunk_size,
    )
    request = (
        service.edits()
        .bundles()
        .upload(packageName=package_name, editId=edit_id, media_body=media)
    )

    response = None
    transient_failures = 0
    while response is None:
        try:
            status, response = request.next_chunk(num_retries=3)
            transient_failures = 0
            if status is not None:
                pct = int(status.progress() * 100)
                print(f"  upload progress: {pct}%", flush=True)
        except HttpError:
            raise
        except (TimeoutError, OSError, httplib2.HttpLib2Error) as exc:
            # RedirectMissingLocation means 308 handling is broken — do not spin.
            if type(exc).__name__ == "RedirectMissingLocation":
                raise SystemExit(
                    "Play resumable upload failed: httplib2 treated HTTP 308 as a "
                    "redirect. This script excludes 308 from redirect_codes; if you "
                    "still see this, upgrade google-auth-httplib2 / httplib2."
                ) from exc
            transient_failures += 1
            if transient_failures > max_retries:
                raise SystemExit(
                    f"Play AAB upload timed out after {max_retries} chunk retries "
                    f"({size_mb:.1f} MiB). Check network stability, or raise "
                    "GOOGLE_PLAY_UPLOAD_TIMEOUT_SEC / GOOGLE_PLAY_UPLOAD_CHUNK_RETRIES."
                ) from exc
            delay = min(2**transient_failures, 30)
            print(
                f"  transient upload error ({type(exc).__name__}: {exc}); "
                f"retry {transient_failures}/{max_retries} in {delay}s...",
                file=sys.stderr,
                flush=True,
            )
            time.sleep(delay)

    if not isinstance(response, dict) or "versionCode" not in response:
        raise SystemExit(f"Unexpected bundle upload response: {response!r}")
    return response


def upload(
    *,
    aab: Path,
    package_name: str,
    track: str,
    status: str,
    credentials_path: Path,
    cleanup_credentials: bool,
) -> None:
    if not aab.is_file():
        raise SystemExit(f"AAB not found: {aab}")

    credentials = service_account.Credentials.from_service_account_file(
        str(credentials_path),
        scopes=SCOPES,
    )
    timeout_sec = _env_int("GOOGLE_PLAY_UPLOAD_TIMEOUT_SEC", DEFAULT_TIMEOUT_SEC)
    # Match googleapiclient.http.build_http(): Google resumable uploads use HTTP 308
    # "Resume Incomplete" (no Location header). httplib2 must not treat 308 as a redirect.
    raw_http = httplib2.Http(timeout=timeout_sec)
    try:
        raw_http.redirect_codes = raw_http.redirect_codes - {308}
    except AttributeError:
        pass
    http = AuthorizedHttp(credentials, http=raw_http)
    service = build("androidpublisher", "v3", http=http, cache_discovery=False)

    edit_id = service.edits().insert(body={}, packageName=package_name).execute()["id"]
    print(f"Created Play edit {edit_id}")

    try:
        bundle = _upload_bundle_resumable(
            service,
            package_name=package_name,
            edit_id=edit_id,
            aab=aab,
        )
        version_code = bundle["versionCode"]
        print(f"Uploaded AAB versionCode={version_code}")

        track_body = {
            "track": track,
            "releases": [
                {
                    "versionCodes": [str(version_code)],
                    "status": status,
                }
            ],
        }
        service.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=track,
            body=track_body,
        ).execute(num_retries=3)
        print(f"Assigned versionCode={version_code} to track={track} status={status}")

        service.edits().commit(packageName=package_name, editId=edit_id).execute(num_retries=3)
        print(f"Committed Play edit {edit_id}")
    except HttpError as exc:
        try:
            service.edits().delete(packageName=package_name, editId=edit_id).execute()
            print(f"Deleted failed Play edit {edit_id}", file=sys.stderr)
        except Exception as cleanup_exc:
            print(f"WARNING: could not delete edit {edit_id}: {cleanup_exc}", file=sys.stderr)
        content = exc.content.decode("utf-8", errors="replace") if exc.content else str(exc)
        if "signed with the wrong key" in content:
            raise SystemExit(
                "Play rejected the AAB: signed with the wrong upload key.\n"
                f"  API detail: {content}\n"
                "Rebuild with the keystore whose SHA1 matches Play Console → "
                "Setup → App signing → Upload key certificate "
                "(android/key.properties). Do not upload a debug-signed AAB."
            ) from exc
        raise SystemExit(f"Play API error {exc.resp.status}: {content}") from exc
    except SystemExit:
        try:
            service.edits().delete(packageName=package_name, editId=edit_id).execute()
            print(f"Deleted failed Play edit {edit_id}", file=sys.stderr)
        except Exception as cleanup_exc:
            print(f"WARNING: could not delete edit {edit_id}: {cleanup_exc}", file=sys.stderr)
        raise
    except Exception:
        try:
            service.edits().delete(packageName=package_name, editId=edit_id).execute()
            print(f"Deleted failed Play edit {edit_id}", file=sys.stderr)
        except Exception as cleanup_exc:
            print(f"WARNING: could not delete edit {edit_id}: {cleanup_exc}", file=sys.stderr)
        raise
    finally:
        if cleanup_credentials:
            try:
                credentials_path.unlink(missing_ok=True)
            except OSError as exc:
                print(f"WARNING: could not remove temp credentials: {exc}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("aab", type=Path, help="Path to the signed .aab")
    parser.add_argument(
        "--package-name",
        default=os.environ.get("GOOGLE_PLAY_PACKAGE_NAME", DEFAULT_PACKAGE),
    )
    parser.add_argument(
        "--track",
        default=os.environ.get("GOOGLE_PLAY_TRACK", DEFAULT_TRACK),
    )
    parser.add_argument(
        "--status",
        default=os.environ.get("GOOGLE_PLAY_RELEASE_STATUS", DEFAULT_STATUS),
    )
    parser.add_argument(
        "--credentials",
        default=None,
        help="Path to service account JSON (else env vars)",
    )
    args = parser.parse_args()

    # Temp file when credentials came from inline JSON / base64 env (not a path).
    cleanup = (
        not args.credentials
        and not os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH", "").strip()
        and (
            bool(os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64", "").strip())
            or bool(os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip())
        )
    )
    cred_path = _resolve_credentials_path(args.credentials)
    try:
        upload(
            aab=args.aab,
            package_name=args.package_name,
            track=args.track,
            status=args.status,
            credentials_path=cred_path,
            cleanup_credentials=cleanup,
        )
    except Exception:
        if cleanup:
            try:
                cred_path.unlink(missing_ok=True)
            except OSError:
                pass
        raise


if __name__ == "__main__":
    main()
