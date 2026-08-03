#!/usr/bin/env python3
import os
import pathlib
import stat
import sys
import tarfile
import zipfile


def within(root: pathlib.Path, candidate: pathlib.Path) -> bool:
    return os.path.commonpath((str(root), str(candidate))) == str(root)


def extract_tar(archive: pathlib.Path, root: pathlib.Path) -> None:
    with tarfile.open(archive, "r:*") as bundle:
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


def extract_zip(archive: pathlib.Path, root: pathlib.Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            destination = (root / member.filename).resolve()
            if not within(root, destination):
                raise SystemExit(f"unsafe SDK archive member: {member.filename}")
            unix_mode = member.external_attr >> 16
            if stat.S_ISLNK(unix_mode):
                raise SystemExit(f"SDK zip symbolic links are not accepted: {member.filename}")
        bundle.extractall(root)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <sdk-archive> <destination>")
    archive = pathlib.Path(sys.argv[1])
    root = pathlib.Path(sys.argv[2]).resolve()
    root.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(archive):
        extract_zip(archive, root)
    elif tarfile.is_tarfile(archive):
        extract_tar(archive, root)
    else:
        raise SystemExit("unsupported SDK archive format")


if __name__ == "__main__":
    main()
