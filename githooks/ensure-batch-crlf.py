#!/usr/bin/env python3
"""Rewrite staged .cmd/.bat files to CRLF and re-stage them.

cmd.exe does not recognize labels in an LF-only batch file. PowerShell
accepts LF, so .ps1 files are left unchanged. Run from a git pre-commit hook.
"""

import subprocess
import sys


def needs_crlf(data: bytes) -> bool:
    previous = 0
    for byte in data:
        if byte == 10 and previous != 13:
            return True
        previous = byte
    return False


def to_crlf(data: bytes) -> bytes:
    out = bytearray()
    previous = 0
    for byte in data:
        if byte == 10 and previous != 13:
            out.append(13)
        out.append(byte)
        previous = byte
    return bytes(out)


def staged_batch_files():
    output = subprocess.check_output(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM", "-z"]
    )
    for name in output.split(b"\0"):
        if not name:
            continue
        path = name.decode("utf-8", "surrogateescape")
        if path.lower().endswith((".cmd", ".bat")):
            yield path


def main() -> int:
    fixed = []
    for path in staged_batch_files():
        try:
            blob = subprocess.check_output(["git", "show", f":{path}"])
        except subprocess.CalledProcessError:
            print(f"Could not read staged batch file: {path}", file=sys.stderr)
            return 1
        if not needs_crlf(blob):
            continue
        try:
            with open(path, "rb") as handle:
                working = handle.read()
        except OSError as error:
            print(f"Could not read {path}: {error}", file=sys.stderr)
            return 1
        # Prefer the working copy so unstaged edits in the same file are kept.
        source = working if needs_crlf(working) else blob
        try:
            with open(path, "wb") as handle:
                handle.write(to_crlf(source))
        except OSError as error:
            print(f"Could not write CRLF to {path}: {error}", file=sys.stderr)
            return 1
        subprocess.check_call(["git", "add", "--", path])
        fixed.append(path)
    if fixed:
        print("Rewrote batch files to CRLF before commit:")
        for path in fixed:
            print(f"  {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
