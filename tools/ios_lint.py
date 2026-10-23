#!/usr/bin/env python3
# =============================================================================
# ARMOR-IOS-CONTROL - tools/ios_lint.py
# Copyright (C) 2026 JuanenRac (Electro Hobby 3D)
# GPL-3.0-or-later - see LICENSE
# =============================================================================
"""Checks of the iPhone app that need no Mac: the structure of the project, the eight language
tables against the phrases the Swift sources use, the HTTP paths against the contract of the
server (the Android client's list of paths, when the repository sits next to it), the permissions
and the secrets that must never be in the sources. The Swift tests of ArmorCore run with
`swift test` where a Swift toolchain exists (Linux or macOS)."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ("en", "de", "fr", "it", "ja", "zh", "pt")
TABLES = ROOT / "Sources" / "ArmorCore" / "Resources" / "i18n"
SWIFT_DIRS = (ROOT / "Sources", ROOT / "App")
PHRASE = re.compile(r'\btrf?\(\s*"((?:[^"\\]|\\.)*)"')
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')

REQUIRED = (
    "Package.swift", "project.yml", "armor.project.json", "CHANGELOG.md", "LICENSE", ".gitignore",
    "Sources/ArmorCore/ArmorApi.swift", "Sources/ArmorCore/ArmorApiClient.swift", "Sources/ArmorCore/ArmorController.swift",
    "Sources/ArmorCore/DeviceLock.swift", "Sources/ArmorCore/Tr.swift", "Sources/ArmorCore/Trust.swift", "Sources/ArmorCore/Reach.swift",
    "App/ArmorApp.swift", "App/AppModel.swift", "App/RootView.swift", "App/LoginView.swift", "App/HomeView.swift", "App/AlarmsView.swift",
    "App/CamerasView.swift", "App/AssistantView.swift", "App/MoreView.swift", "App/LockedView.swift", "App/HelpView.swift",
    "App/Platform/BiometricAuth.swift", "App/Platform/KeychainSecrets.swift", "App/Platform/TrustDelegate.swift", "App/Platform/Push.swift",
    "App/Resources/Assets.xcassets/Contents.json",
)
INFO_LANGS = ("en", "es", "de", "fr", "it", "ja", "zh-Hans", "pt-PT")
REQUIRED_PLIST_KEYS = ("NSFaceIDUsageDescription", "NSLocalNetworkUsageDescription", "NSAllowsLocalNetworking", "CFBundleLocalizations")
FORBIDDEN = (
    (re.compile(r"NSAllowsArbitraryLoads"), "App Transport Security is opened wide"),
    (re.compile(r'(?i)password\s*[:=]\s*"[^"$\\]{3,}"'), "a literal password"),
    (re.compile(r"(?i)rtsp://"), "an RTSP address: the app never knows the camera"),
    (re.compile(r"(?i)print\(.*(password|pin|cookie|token)"), "a log line that may print a secret"),
)


def swift_files() -> list[Path]:
    return [p for base in SWIFT_DIRS for p in sorted(base.rglob("*.swift"))]


def unescape(text: str) -> str:
    return text.replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")


def phrases() -> dict[str, list[str]]:
    """Every Spanish phrase the sources send through tr/trf, and where."""
    found: dict[str, list[str]] = {}

    def add(text: str, where: str) -> None:
        found.setdefault(unescape(text), []).append(where)

    for path in swift_files():
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        source = path.read_text(encoding="utf-8")
        for match in PHRASE.finditer(source):
            add(match.group(1), rel)
        if rel.endswith("AlarmText.swift"):
            for match in re.finditer(r'^\s+"[a-z_0-9]+":\s*"((?:[^"\\]|\\.)*)",\s*$', source, re.M):
                add(match.group(1), rel)
        if rel.endswith("HelpView.swift"):
            block = source.split("static let topics", 1)[1].split("\n    ]", 1)[0]
            for line in block.splitlines():
                literals = LITERAL.findall(line)
                if len(literals) == 2:
                    for literal in literals:
                        add(literal, rel)
    return found


def check_structure(problems: list[str]) -> None:
    for name in REQUIRED:
        if not (ROOT / name).is_file():
            problems.append(f"missing file: {name}")
    for code in INFO_LANGS:
        strings = ROOT / "App" / "Resources" / f"{code}.lproj" / "InfoPlist.strings"
        if not strings.is_file():
            problems.append(f"missing InfoPlist.strings for {code}")
        else:
            text = strings.read_text(encoding="utf-8")
            if "NSFaceIDUsageDescription" not in text or "NSLocalNetworkUsageDescription" not in text:
                problems.append(f"{code}: InfoPlist.strings without the Face ID or local network text")
    project = (ROOT / "project.yml").read_text(encoding="utf-8") if (ROOT / "project.yml").is_file() else ""
    for key in REQUIRED_PLIST_KEYS:
        if key not in project:
            problems.append(f"project.yml lacks {key}")
    if "NSAllowsArbitraryLoads" in project:
        problems.append("project.yml opens App Transport Security wide")
    package = (ROOT / "Package.swift").read_text(encoding="utf-8") if (ROOT / "Package.swift").is_file() else ""
    for needle in ("ArmorCore", "ArmorCoreTests", "swift-tools-version"):
        if needle not in package:
            problems.append(f"Package.swift lacks {needle}")
    # the package must stay free of UI frameworks so that it builds and is tested on Linux
    for path in sorted((ROOT / "Sources").rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        if re.search(r"^import (SwiftUI|UIKit|LocalAuthentication|Security|CryptoKit|Combine)\b", text, re.M):
            problems.append(f"{path.relative_to(ROOT)}: ArmorCore must not import a platform framework")
    tests = list((ROOT / "Tests" / "ArmorCoreTests").glob("*Tests.swift"))
    if len(tests) < 8:
        problems.append("fewer than eight test files in Tests/ArmorCoreTests")


# a Swift interpolation, with one level of parentheses inside: \(name) or \(Self.part(id))
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
HOLE = re.compile(r"%(?:\d+\$)?[sd]")


def holes(text: str) -> int:
    return len(HOLE.findall(text))


def check_languages(problems: list[str]) -> None:
    tables: dict[str, dict[str, str]] = {}
    for code in LANGS:
        path = TABLES / f"{code}.json"
        if not path.is_file():
            problems.append(f"missing language table {code}.json")
            continue
        tables[code] = json.loads(path.read_text(encoding="utf-8"))
    used = phrases()
    if not used:
        problems.append("no phrases found in the sources")
    for code, table in tables.items():
        for phrase in used:
            if phrase not in table:
                problems.append(f"{code}: no translation for {phrase[:70]!r} ({used[phrase][0]})")
            elif not table[phrase].strip():
                problems.append(f"{code}: empty translation for {phrase[:70]!r}")
            elif holes(phrase) != holes(table[phrase]):
                problems.append(f"{code}: the holes of {phrase[:70]!r} changed in translation")
        for phrase in table:
            if phrase not in used:
                problems.append(f"{code}: phrase no longer used: {phrase[:70]!r}")
    # the portuguese of the tables is the one of Portugal: a few words that only Brazil uses
    brazilian = re.compile(r"\b(você|vocês|celular|tela|arquivo|usuário|senha)\b", re.I)
    for text in tables.get("pt", {}).values():
        if brazilian.search(text):
            problems.append(f"pt: Brazilian wording in {text[:60]!r}")
    # no hard-coded user-facing text in the screens outside tr()
    allowed = {"A.R.M.O.R.", "armor-pin:…", "bypass", "192.168.0.180", "https://casa.duckdns.org"}
    for path in sorted((ROOT / "App").glob("*.swift")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for pattern in (r'\bText\(\s*"', r'\bButton\(\s*"', r'\bToggle\(\s*"', r'\bLabel\(\s*"', r'navigationTitle\(\s*"'):
                match = re.search(pattern + r'([^"]*)"', line)
                shown = INTERPOLATION.sub("", match.group(1)) if match else ""
                if match and re.search(r"[A-Za-zÁ-ú]{3,}", shown) and match.group(1) not in allowed:
                    problems.append(f"{path.name}:{number}: text outside tr(): {match.group(1)[:40]!r}")


def server_paths_of_swift() -> set[str]:
    paths: set[str] = set()
    source = (ROOT / "Sources/ArmorCore/ArmorApiClient.swift").read_text(encoding="utf-8")
    for match in re.finditer(r'"(/api/v1/[^"?]*)', source):
        paths.add(INTERPOLATION.sub("{}", match.group(1)))
    return paths


def check_contract(problems: list[str]) -> None:
    """Every path the app calls is a path the Android client calls too (the two clients speak the same contract), and the contract of COMMON knows it when the sibling is there."""
    android = ROOT.parent / "ARMOR-ANDROID-CONTROL" / "app/src/main/java/es/electrohobby3d/armor/network/ArmorApiClient.kt"
    swift = server_paths_of_swift()
    if not swift:
        problems.append("no API paths found in ArmorApiClient.swift")
        return
    if android.is_file():
        known = set()
        for match in re.finditer(r'"(/api/v1/[^"?]*)', android.read_text(encoding="utf-8")):
            known.add(re.sub(r"\$\{[^}]*\}", "{}", match.group(1)).rstrip("/"))
        for path in sorted(swift):
            if path.rstrip("/") not in known:
                problems.append(f"the app calls {path}, which the Android client does not")
    openapi = ROOT.parent / "ARMOR-COMMON" / "openapi" / "armor-server.yaml"
    if openapi.is_file():
        text = openapi.read_text(encoding="utf-8")
        for path in sorted(swift):
            head = path.split("{", 1)[0].rstrip("/")
            if head not in text:
                problems.append(f"{path} is not in the OpenAPI of ARMOR-COMMON")


def check_secrets(problems: list[str]) -> None:
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        for pattern, why in FORBIDDEN:
            if pattern.search(text):
                problems.append(f"{path.relative_to(ROOT)}: {why}")
    if list(ROOT.rglob("GoogleService-Info.plist")):
        problems.append("GoogleService-Info.plist must not be in the repository")


def check_public_text(problems: list[str]) -> None:
    banned = re.compile(r"(?i)\b(claude|anthropic|auditor[ií]a|SONNET)\b")
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or any(part in {".git", ".build", ".swiftpm", "__pycache__"} for part in path.parts):
            continue
        if path.suffix in {".swift", ".md", ".yml", ".yaml", ".json", ".py", ".strings", ".txt", ".svg"} and path.name != "ios_lint.py":
            if banned.search(path.read_text(encoding="utf-8", errors="ignore")):
                problems.append(f"{path.relative_to(ROOT)}: wording that does not belong in a public repository")


def main() -> int:
    problems: list[str] = []
    check_structure(problems)
    check_languages(problems)
    check_contract(problems)
    check_secrets(problems)
    check_public_text(problems)
    if problems:
        for problem in problems:
            print(f"IOS_LINT=FAIL {problem}", file=sys.stderr)
        print(f"IOS_LINT=FAIL {len(problems)} problems", file=sys.stderr)
        return 1
    used = phrases()
    print(f"IOS_LINT=PASS {len(swift_files())} Swift files, {len(used)} phrases in {len(LANGS) + 1} languages, {len(server_paths_of_swift())} server paths")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
