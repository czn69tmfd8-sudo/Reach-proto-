#!/usr/bin/env python3
"""Fail-closed offline Adventure Book emulator configuration.

Never deploys rules or connects to a live Firebase project.
"""
import json
from pathlib import Path

PROJECT = "demo-reach-adventure"
FIRESTORE = "adventure-book.combined.generated.rules"
STORAGE = "adventure-book.storage.proposed.rules"
CONFIG = "adventure-emulator.generated.json"

def prepare(root: Path):
    root = Path(root)
    rules = {}
    for service, filename in (("firestore", FIRESTORE), ("storage", STORAGE)):
        path = root / filename
        if not path.is_file():
            raise RuntimeError(f"Missing {service} rules: {path}")
        contents = path.read_text()
        expected = "service cloud.firestore" if service == "firestore" else "service firebase.storage"
        if "rules_version = '2';" not in contents or expected not in contents:
            raise RuntimeError(f"Invalid or missing {service} security policy in {path}")
        if "allow " not in contents:
            raise RuntimeError(f"No explicit {service} permissions found in {path}")
        rules[service] = {"rules": filename}
    rules["emulators"] = {
        "firestore": {"host": "127.0.0.1", "port": 8080},
        "storage": {"host": "127.0.0.1", "port": 9199},
        "ui": {"enabled": False},
        "singleProjectMode": True,
    }
    config_path = root / CONFIG
    config_path.write_text(json.dumps(rules, indent=2) + "\n")
    check = json.loads(config_path.read_text())
    for service in ("firestore", "storage"):
        if check[service]["rules"] != (FIRESTORE if service == "firestore" else STORAGE):
            raise RuntimeError(f"Missing {service} rules in emulator configuration")
        if check["emulators"][service]["port"] not in (8080, 9199):
            raise RuntimeError(f"Missing {service} emulator port")
    return config_path

if __name__ == "__main__":
    path = prepare(Path.cwd())
    print(f"Validated local-only emulator configuration: {path}")
