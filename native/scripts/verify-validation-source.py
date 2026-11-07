#!/usr/bin/env python3
"""Require approved app bytes, with only the reviewed test-fixture correction."""
from pathlib import Path
import subprocess
import sys

FIXTURE = 'native/REACHTests/ReachHomeAvailabilityTests.swift'
OLD_FIXTURE = '        var outsider = pair(); outsider.hostUid = "outsider"'
NEW_FIXTURE = '''        let outsider = PairRecord(hostUid: "outsider", partnerUid: "partner", revoked: false,
                                  activeRoom: "room", openedBy: "partner")'''


def verify(commit, repository):
    repository = Path(repository)
    subprocess.run(['git', 'diff', '--exit-code', commit, '--', 'native/REACH', 'native/project.yml'], cwd=repository, check=True, stdout=subprocess.PIPE)
    changed = subprocess.check_output(['git', 'diff', '--name-only', commit, '--', 'native/REACHTests'], cwd=repository, text=True).splitlines()
    for path in changed:
        if path != FIXTURE:
            raise ValueError('Unreviewed test source change: ' + path)
        original = subprocess.check_output(['git', 'show', commit + ':' + path], cwd=repository, text=True)
        if original.count(OLD_FIXTURE) != 1:
            raise ValueError('Approved fixture context differs; review the new baseline.')
        expected = original.replace(OLD_FIXTURE, NEW_FIXTURE, 1)
        if (repository / path).read_text() != expected:
            raise ValueError('Only the reviewed immutable outsider-fixture correction is permitted.')


if __name__ == '__main__':
    try:
        verify(sys.argv[1], Path(__file__).resolve().parents[2])
        print('Approved app/project source unchanged; test changes limited to the reviewed outsider fixture.')
    except (ValueError, subprocess.CalledProcessError, IndexError) as error:
        raise SystemExit(str(error))
