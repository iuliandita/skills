#!/usr/bin/env python3
"""Exercise publication timing and notice/replacement validation in temporary fixtures."""

import importlib.util
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("checker", Path(__file__).with_name("check-migrations.py"))
assert spec and spec.loader
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class MigrationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = {
            "version": 1,
            "transition": {"release": None, "published_at": None, "minimum_days": 7, "placeholder_releases": 1},
            "skills": {"old": {"action": "rename", "replacement": "new"}},
        }
        for name in ("old", "new"):
            path = self.root / "skills" / name / "SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text(f'---\nname: {name}\ndescription: Deprecated name\nmetadata:\n  deprecated: "{str(name == "old").lower()}"\n---\nUse **new**.\n')
        self.write()

    def write(self):
        (self.root / "migrations.json").write_text(json.dumps(self.manifest))

    def publish(self, days):
        self.manifest["transition"].update(release="v1.0.0", published_at=(datetime.now(timezone.utc) - timedelta(days=days)).isoformat())
        self.write()

    def test_unpublished_notices_valid_but_retirement_blocked(self):
        checker.validate(self.root)
        with self.assertRaises(ValueError):
            checker.validate(self.root, retire=True)

    def test_premature_deletion_rejected(self):
        self.publish(6)
        (self.root / "skills/old/SKILL.md").unlink()
        with self.assertRaises(ValueError):
            checker.validate(self.root)

    def test_seven_days_allows_retirement(self):
        self.publish(7)
        (self.root / "skills/old/SKILL.md").unlink()
        checker.validate(self.root, retire=True)

    def test_date_without_release_rejected(self):
        self.publish(8)
        self.manifest["transition"]["release"] = None
        self.write()
        with self.assertRaises(ValueError):
            checker.validate(self.root)

    def test_missing_replacement_rejected(self):
        (self.root / "skills/new/SKILL.md").unlink()
        with self.assertRaises(OSError):
            checker.validate(self.root)

    def test_path_traversal_rejected(self):
        self.manifest["skills"]["old"]["replacement"] = "../new"
        self.write()
        with self.assertRaises(ValueError):
            checker.validate(self.root)


if __name__ == "__main__":
    unittest.main()
