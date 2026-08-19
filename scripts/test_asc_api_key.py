#!/usr/bin/env python3
"""Tests for App Store Connect key-id recovery (run before changing the uploader)."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from asc_api_key import is_valid_asc_key_id, resolve_asc_key_id


class ValidKeyIdTests(unittest.TestCase):
    def test_ten_alnum_is_valid(self) -> None:
        self.assertTrue(is_valid_asc_key_id("2X9R4HXF34"))

    def test_placeholder_from_apple_is_invalid(self) -> None:
        self.assertFalse(is_valid_asc_key_id("from Apple"))

    def test_empty_is_invalid(self) -> None:
        self.assertFalse(is_valid_asc_key_id(""))

    def test_wrong_length_is_invalid(self) -> None:
        self.assertFalse(is_valid_asc_key_id("SHORT"))
        self.assertFalse(is_valid_asc_key_id("TOOLONGKEY1"))


class ResolveKeyIdTests(unittest.TestCase):
    def test_keeps_a_valid_env_key_id(self) -> None:
        self.assertEqual(
            resolve_asc_key_id("2X9R4HXF34", private_key="-----BEGIN PRIVATE KEY-----"),
            "2X9R4HXF34",
        )

    def test_recovers_key_id_from_authkey_filename(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p8 = Path(tmp) / "AuthKey_AB12CD34EF.p8"
            p8.write_text("-----BEGIN PRIVATE KEY-----\nMIGH\n-----END PRIVATE KEY-----\n")
            self.assertEqual(
                resolve_asc_key_id("from Apple", private_key=str(p8)),
                "AB12CD34EF",
            )

    def test_recovers_from_codemagic_style_72_char_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            # Matches the Codemagic log: kind=file-pem src_len=72
            nested = Path(tmp) / "builder" / "keys"
            nested.mkdir(parents=True)
            p8 = nested / "AuthKey_Z9Y8X7W6V5.p8"
            p8.write_text("-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----\n")
            self.assertEqual(
                resolve_asc_key_id("from Apple", private_key=str(p8)),
                "Z9Y8X7W6V5",
            )

    def test_placeholder_without_authkey_path_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, "not a Key ID"):
            resolve_asc_key_id("from Apple", private_key="-----BEGIN PRIVATE KEY-----")

    def test_scans_search_dirs_for_authkey_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p8 = Path(tmp) / "AuthKey_Q1W2E3R4T5.p8"
            p8.write_text("-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----\n")
            self.assertEqual(
                resolve_asc_key_id(
                    "from Apple",
                    private_key="-----BEGIN PRIVATE KEY-----",
                    search_dirs=[tmp],
                ),
                "Q1W2E3R4T5",
            )


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parent)
    unittest.main()
