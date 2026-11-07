#!/usr/bin/env python3
"""Check seekable and append-mode standard output through the guest APIs."""
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "output.bin"
    for mode, expected in (("wb", b"ZBC"), ("ab", b"ABCZ")):
        path.unlink(missing_ok=True)
        with path.open(mode) as stream:
            subprocess.run(sys.argv[1:], stdout=stream, check=True)
        actual = path.read_bytes()
        assert actual == expected, (mode, actual, expected)
