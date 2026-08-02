#!/usr/bin/env python3
import os
import pathlib
import sys
import tarfile


def within(root: pathlib.Path, candidate: pathlib.Path) -> bool:
    return os.path.commonpath((str(root), str(candidate))) == str(root)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <archive.tar.gz> <destination>")

    archive = pathlib.Path(sys.argv[1])
    root = pathlib.Path(sys.argv[2]).resolve()
    root.mkdir(parents=True, exist_ok=True)

    with tarfile.open(archive, "r:gz") as bundle:
        for member in bundle.getmembers():
            destination = (root / member.name).resolve()
            if not within(root, destination):
                raise SystemExit(f"unsafe SDK archive member: {member.name}")

            if member.issym():
                link_target = (destination.parent / member.linkname).resolve()
                if not within(root, link_target):
                    raise SystemExit(f"unsafe SDK archive link: {member.name}")
            elif member.islnk():
                link_target = (root / member.linkname).resolve()
                if not within(root, link_target):
                    raise SystemExit(f"unsafe SDK archive link: {member.name}")

        if sys.version_info >= (3, 11):
            bundle.extractall(root, filter="fully_trusted")
        else:
            bundle.extractall(root)


if __name__ == "__main__":
    main()
