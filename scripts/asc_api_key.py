"""Resolve App Store Connect API Key ID from env or AuthKey_*.p8 filename."""

from __future__ import annotations

import re
from collections.abc import Iterable
from pathlib import Path

_KEY_ID_RE = re.compile(r"^[A-Za-z0-9]{10}$")
_AUTHKEY_RE = re.compile(r"AuthKey_([A-Za-z0-9]{10})\.p8$", re.IGNORECASE)


def is_valid_asc_key_id(value: str | None) -> bool:
    return bool(value) and _KEY_ID_RE.fullmatch(value or "") is not None


def _key_id_from_name(name: str) -> str | None:
    match = _AUTHKEY_RE.search(name.replace("\\", "/"))
    return match.group(1) if match else None


def resolve_asc_key_id(
    identifier: str | None,
    private_key: str | None = "",
    search_dirs: Iterable[str] | None = None,
) -> str:
    """Return a 10-character Key ID.

    Codemagic's Developer Portal form is labeled "Key ID from Apple". If the
    field is left as the placeholder ``from Apple``, recover the id from an
    uploaded ``AuthKey_<id>.p8`` path (the previous IPA log had kind=file-pem
    src_len=72).
    """
    if is_valid_asc_key_id(identifier):
        return identifier  # type: ignore[return-value]

    raw = (private_key or "").strip().strip('"').strip("'")
    if raw.startswith("@file:"):
        raw = raw[len("@file:") :]

    from_path = _key_id_from_name(raw)
    if from_path:
        return from_path

    path = Path(raw)
    if path.is_file():
        from_name = _key_id_from_name(path.name)
        if from_name:
            return from_name

    for directory in search_dirs or []:
        folder = Path(directory)
        if not folder.is_dir():
            continue
        matches = []
        for candidate in folder.glob("AuthKey_*.p8"):
            kid = _key_id_from_name(candidate.name)
            if kid and is_valid_asc_key_id(kid):
                matches.append(kid)
        unique = sorted(set(matches))
        if len(unique) == 1:
            return unique[0]

    shown = identifier or "(empty)"
    raise ValueError(
        f"APP_STORE_CONNECT_KEY_IDENTIFIER is {shown!r} — that is not a Key ID. "
        "Copy the 10-character Key ID from App Store Connect (like 2X9R4HXF34). "
        "Do not type 'from Apple'."
    )
