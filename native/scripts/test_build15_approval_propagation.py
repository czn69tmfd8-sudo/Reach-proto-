"""Execute the real export-step shell with harmless command stubs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Build15ApprovalPropagationTests(unittest.TestCase):
    def workflow(self):
        return (ROOT/'codemagic.yaml').read_text().split(
            '  reach-adventure-single-app-signed-archive-hold:', 1)[1].split(
            '\n  reach-ios-simulator:', 1)[0]

    def run_export(self, selected):
        text = self.workflow().split(
            '      - name: Export and upload only with explicit internal Build 15 authorization\n', 1)[1]
        text = text.split('    artifacts:', 1)[0].split('        script: |\n', 1)[1]
        script = '\n'.join(line[10:] for line in text.splitlines())
        script = script.replace('${{ inputs.archive_approval }}', selected)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'native/build-logs').mkdir(parents=True)
            commands = root/'commands'; commands.mkdir()
            trace = root/'trace'
            # Stub only commands that would sign/export/upload. The actual Bash
            # condition, input interpolation and process environment are exercised.
            for name in ['python3', 'xcodebuild']:
                stub = commands/name
                stub.write_text('#!/bin/bash\nprintf "%s|%s|%s\\n" "$(basename "$0")" "$REACH_SIGNED_ARCHIVE_APPROVAL" "$*" >> "$TRACE"\n'
                                'if [[ "$1" == *upload-build15.py && "$2" == preflight ]]; then\n'
                                '  [[ "$REACH_SIGNED_ARCHIVE_APPROVAL" == UPLOAD_INTERNAL_BUILD_15 ]] || exit 1\nfi\n')
                stub.chmod(0o700)
            env = {**os.environ, 'PATH': str(commands)+os.pathsep+os.environ['PATH'],
                   'TRACE': str(trace), 'REACH_SIGNED_ARCHIVE_APPROVAL': 'APPROVE_SINGLE_APP_ARCHIVE_ONLY'}
            result = subprocess.run(['bash', '-c', script], cwd=root, env=env, capture_output=True, text=True)
            return result, trace.read_text() if trace.exists() else ''

    def test_upload_input_overrides_stale_archive_environment_and_reaches_upload(self):
        result, trace = self.run_export('UPLOAD_INTERNAL_BUILD_15')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('effective approval: UPLOAD_INTERNAL_BUILD_15', result.stdout)
        self.assertNotIn('Archive-only selection', result.stdout)
        self.assertIn('xcodebuild|UPLOAD_INTERNAL_BUILD_15|-exportArchive', trace)
        self.assertIn('python3|UPLOAD_INTERNAL_BUILD_15|scripts/upload-build15.py upload', trace)
        self.assertLess(trace.index('promote-ipa'), trace.index('scripts/upload-build15.py upload'))

    def test_archive_choice_still_exits_without_export_or_upload(self):
        result, trace = self.run_export('APPROVE_SINGLE_APP_ARCHIVE_ONLY')
        self.assertEqual(result.returncode, 0)
        self.assertIn('Archive-only selection', result.stdout)
        self.assertEqual(trace, '')

    def test_missing_hold_or_unresolved_input_fails_before_export(self):
        for selected in ['', 'HOLD', '${{ inputs.archive_approval }}']:
            with self.subTest(selected=selected):
                result, trace = self.run_export(selected)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('xcodebuild', trace)
                self.assertNotIn('scripts/upload-build15.py upload', trace)

    def test_both_steps_bind_same_input_and_manual_default_is_authorized_upload(self):
        workflow = self.workflow()
        self.assertEqual(workflow.count('export REACH_SIGNED_ARCHIVE_APPROVAL="${{ inputs.archive_approval }}"'), 2)
        self.assertIn('default: "UPLOAD_INTERNAL_BUILD_15"', workflow)
        self.assertNotIn('triggering:', workflow)
