#!/usr/bin/env python3
import argparse
import json
import struct
from pathlib import Path


MACHINES = {
    "aarch64": 183,
    "x86_64": 62,
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--machine", choices=sorted(MACHINES), required=True)
    args = parser.parse_args()

    header = args.binary.read_bytes()[:64]
    if len(header) < 20 or header[:4] != b"\x7fELF":
        raise SystemExit(f"not an ELF binary: {args.binary}")
    if header[4] != 2:
        raise SystemExit(f"expected ELF64 binary: {args.binary}")
    if header[5] not in (1, 2):
        raise SystemExit(f"unsupported ELF byte order: {args.binary}")
    byte_order = "<" if header[5] == 1 else ">"
    machine = struct.unpack(f"{byte_order}H", header[18:20])[0]
    expected = MACHINES[args.machine]
    if machine != expected:
        raise SystemExit(
            f"ELF machine mismatch for {args.binary}: expected {expected}, got {machine}"
        )
    print(json.dumps({
        "ok": True,
        "binary": str(args.binary),
        "elfClass": 64,
        "byteOrder": "little" if header[5] == 1 else "big",
        "machine": args.machine,
        "machineId": machine,
        "status": "elf-target-verified",
    }))


if __name__ == "__main__":
    main()
