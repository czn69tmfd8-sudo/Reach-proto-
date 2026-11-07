#!/usr/bin/env python3
"""Verify the sprint build inputs against an approved Git commit."""
import os
from pathlib import Path
import stat
import subprocess
import sys

SOURCE_PATHS = (
    'native/REACH',
    'native/REACHTests',
    'native/Configuration',
    'native/project.yml',
)


def verify(commit, repository):
    repository = Path(repository)

    def git(*args):
        return subprocess.check_output(['git', *args], cwd=repository, stderr=subprocess.PIPE)

    approved = git('ls-tree', '-rz', commit, '--', *SOURCE_PATHS)
    if git('ls-tree', '-rz', 'HEAD', '--', *SOURCE_PATHS) != approved:
        raise ValueError('Committed sprint source differs from the approved commit.')

    expected = {}
    for entry in approved.split(b'\0'):
        if entry:
            metadata, path = entry.split(b'\t', 1)
            mode, kind, oid = metadata.decode('ascii').split()
            if kind != 'blob' or mode not in ('100644', '100755'):
                raise ValueError(f'Unsupported source entry: {os.fsdecode(path)}')
            expected[os.fsdecode(path)] = (mode, oid)

    if not stat.S_ISDIR((repository / 'native').lstat().st_mode):
        raise ValueError('Expected a real native source directory.')

    # Inspect disk directly: Git status can omit ignored or assume-unchanged files.
    pending = [repository / path for path in SOURCE_PATHS]
    while pending:
        path = pending.pop()
        relative = path.relative_to(repository).as_posix()
        mode = path.lstat().st_mode
        if stat.S_ISDIR(mode):
            pending.extend(path.iterdir())
            continue
        if not stat.S_ISREG(mode) or relative not in expected:
            raise ValueError(f'Unexpected source entry: {relative}')
        approved_mode, oid = expected.pop(relative)
        actual_mode = '100755' if mode & stat.S_IXUSR else '100644'
        if actual_mode != approved_mode or path.read_bytes() != git('cat-file', 'blob', oid):
            raise ValueError(f'Working source differs from the approved commit: {relative}')

    if expected:
        raise ValueError(f'Approved source is missing: {min(expected)}')


if __name__ == '__main__':
    try:
        verify(sys.argv[1], Path(__file__).resolve().parents[2])
    except subprocess.CalledProcessError as error:
        raise SystemExit(f'Sprint source verification failed: {error.stderr.decode(errors="replace").strip()}')
    except (IndexError, OSError, ValueError) as error:
        raise SystemExit(f'Sprint source verification failed: {error}')
    print(f'Sprint build inputs match approved commit {sys.argv[1]}.')
