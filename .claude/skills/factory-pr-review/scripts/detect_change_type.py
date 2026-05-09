#!/usr/bin/env python3
"""
detect_change_type.py — Classifies a PR according to the modified files.

Returns a JSON with flags that the skill uses to decide which references
to load and which rules to apply.

Usage:
    python detect_change_type.py --files-list files.txt
    python detect_change_type.py --git-range main..HEAD
    gh pr diff <PR> --name-only | python detect_change_type.py --stdin

Output (JSON to stdout):
    {
      "has_code": true,
      "has_openapi": false,
      "has_asyncapi": false,
      "has_docs": false,
      "has_infra": false,
      "has_migrations": false,
      "has_dependencies": false,
      "has_tests": true,
      "is_public_api_touched": false,
      "is_breaking_candidate": false,
      "potential_secrets": false,
      "size": "small",
      "lines_changed": 42,
      "files_changed": 3,
      "languages": ["python"],
      "files": {...}
    }
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

# Classification patterns
CODE_EXTENSIONS = {
    ".py": "python", ".pyi": "python",
    ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
    ".jsx": "javascript",
    ".ts": "typescript", ".tsx": "typescript",
    ".java": "java", ".kt": "kotlin", ".scala": "scala",
    ".go": "go",
    ".rs": "rust",
    ".rb": "ruby",
    ".php": "php",
    ".cs": "csharp",
    ".cpp": "cpp", ".cc": "cpp", ".cxx": "cpp", ".c": "c", ".h": "c", ".hpp": "cpp",
    ".swift": "swift",
    ".sh": "shell", ".bash": "shell",
    ".sql": "sql",
}

DOC_PATTERNS = [
    r"\.md$", r"\.mdx$", r"\.rst$", r"\.adoc$", r"\.txt$",
    r"^docs/", r"^doc/", r"^documentation/",
    r"README", r"CHANGELOG", r"CONTRIBUTING", r"NOTICE", r"AUTHORS",
]

OPENAPI_PATTERNS = [
    r"openapi.*\.(ya?ml|json)$",
    r"swagger.*\.(ya?ml|json)$",
    r"api[-_]spec.*\.(ya?ml|json)$",
]

ASYNCAPI_PATTERNS = [
    r"asyncapi.*\.(ya?ml|json)$",
]

INFRA_PATTERNS = [
    r"Dockerfile", r"docker-compose", r"\.dockerignore$",
    r"\.tf$", r"\.tfvars$",
    r"helm/", r"Chart\.ya?ml$", r"values.*\.ya?ml$",
    r"^k8s/", r"^kubernetes/", r"^manifests/",
    r"^\.github/workflows/", r"^\.gitlab-ci",
    r"jenkinsfile", r"\.circleci/",
    r"\.ansible/", r"playbook.*\.ya?ml$",
]

MIGRATION_PATTERNS = [
    r"migrations/", r"migrate/", r"alembic/", r"flyway/", r"liquibase/",
    r"db/migrate/",
]

DEPENDENCY_FILES_EXACT = {
    "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
    "requirements.txt", "Pipfile", "Pipfile.lock",
    "pyproject.toml", "poetry.lock", "uv.lock",
    "go.mod", "go.sum",
    "pom.xml", "build.gradle", "build.gradle.kts", "gradle.lockfile",
    "Cargo.toml", "Cargo.lock",
    "Gemfile", "Gemfile.lock",
    "composer.json", "composer.lock",
    "packages.config",
}

DEPENDENCY_FILES_REGEX = [
    r"^requirements-.+\.txt$",
    r"\.csproj$",
]

TEST_PATTERNS = [
    r"^tests?/", r"_test\.", r"\.test\.", r"\.spec\.",
    r"^spec/", r"__tests__/",
]

# Public endpoints: heuristic by path
PUBLIC_API_PATH_PATTERNS = [
    r"src/api/", r"src/controllers/", r"src/routes/", r"src/handlers/",
    r"app/controllers/", r"app/api/",
    r"internal/api/", r"pkg/api/",
    r"controllers?/", r"routes?/",
    r"resources?/.*Resource\.", r".*Controller\.",
]

# Basic secret patterns (not exhaustive — complement with tools like gitleaks)
SECRET_PATTERNS = [
    r"-----BEGIN (RSA |EC |DSA |OPENSSH |PRIVATE) ?KEY-----",
    r"AKIA[0-9A-Z]{16}",                                # AWS access key
    r"(?i)aws[_-]?secret[_-]?access[_-]?key.{0,3}[:=].{0,3}['\"][A-Za-z0-9/+=]{40}['\"]",
    r"ghp_[A-Za-z0-9]{36}",                             # GitHub PAT
    r"gho_[A-Za-z0-9]{36}",
    r"sk-[A-Za-z0-9]{20,}",                             # OpenAI / Anthropic style
    r"xox[baprs]-[0-9A-Za-z\-]{10,}",                   # Slack
    r"(?i)api[_-]?key.{0,3}[:=].{0,3}['\"][A-Za-z0-9_\-]{20,}['\"]",
    r"(?i)password.{0,3}[:=].{0,3}['\"][^'\"]{8,}['\"]",
]


def matches_any(path: str, patterns) -> bool:
    return any(re.search(p, path) for p in patterns)


def classify_file(path: str) -> dict:
    p = Path(path)
    ext = p.suffix.lower()
    name = p.name

    return {
        "is_code": ext in CODE_EXTENSIONS and not matches_any(path, TEST_PATTERNS),
        "is_test": matches_any(path, TEST_PATTERNS),
        "is_doc": matches_any(path, DOC_PATTERNS),
        "is_openapi": matches_any(path, OPENAPI_PATTERNS),
        "is_asyncapi": matches_any(path, ASYNCAPI_PATTERNS),
        "is_infra": matches_any(path, INFRA_PATTERNS),
        "is_migration": matches_any(path, MIGRATION_PATTERNS),
        "is_dependency": (
            name in DEPENDENCY_FILES_EXACT
            or any(re.search(pattern, name) for pattern in DEPENDENCY_FILES_REGEX)
        ),
        "is_public_api": matches_any(path, PUBLIC_API_PATH_PATTERNS),
        "language": CODE_EXTENSIONS.get(ext),
    }


def estimate_size(lines_changed: int, files_changed: int) -> str:
    if lines_changed <= 100 and files_changed <= 5:
        return "small"
    if lines_changed <= 500 and files_changed <= 20:
        return "medium"
    return "large"


def detect_secrets_in_diff(diff_text: str) -> bool:
    """Basic heuristic. For production use gitleaks or trufflehog."""
    for pattern in SECRET_PATTERNS:
        if re.search(pattern, diff_text):
            return True
    return False


def get_files_from_git(git_range: str):
    out = subprocess.check_output(
        ["git", "diff", "--name-only", git_range],
        text=True,
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def get_diff_stats(git_range: str):
    out = subprocess.check_output(
        ["git", "diff", "--shortstat", git_range],
        text=True,
    )
    # e.g. " 3 files changed, 42 insertions(+), 8 deletions(-)"
    files = ins = dels = 0
    m = re.search(r"(\d+) files? changed", out)
    if m:
        files = int(m.group(1))
    m = re.search(r"(\d+) insertions?\(\+\)", out)
    if m:
        ins = int(m.group(1))
    m = re.search(r"(\d+) deletions?\(-\)", out)
    if m:
        dels = int(m.group(1))
    return files, ins + dels


def get_diff_text(git_range: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "diff", git_range],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--files-list", type=Path, help="File with one path per line")
    src.add_argument("--git-range", help="Git range, e.g. main..HEAD")
    src.add_argument("--stdin", action="store_true", help="Read paths from stdin")
    parser.add_argument("--check-secrets", action="store_true", help="Scan the diff for secrets")
    args = parser.parse_args()

    # Get list of files
    if args.files_list:
        files = [line.strip() for line in args.files_list.read_text().splitlines() if line.strip()]
        files_changed = len(files)
        lines_changed = 0
        diff_text = ""
    elif args.git_range:
        files = get_files_from_git(args.git_range)
        files_changed, lines_changed = get_diff_stats(args.git_range)
        diff_text = get_diff_text(args.git_range) if args.check_secrets else ""
    else:  # stdin
        files = [line.strip() for line in sys.stdin if line.strip()]
        files_changed = len(files)
        lines_changed = 0
        diff_text = ""

    # Classify
    classified = {f: classify_file(f) for f in files}

    languages = sorted({
        c["language"] for c in classified.values()
        if c.get("language")
    })

    has_code = any(c["is_code"] for c in classified.values())
    has_tests = any(c["is_test"] for c in classified.values())
    has_docs = any(c["is_doc"] for c in classified.values())
    has_openapi = any(c["is_openapi"] for c in classified.values())
    has_asyncapi = any(c["is_asyncapi"] for c in classified.values())
    has_infra = any(c["is_infra"] for c in classified.values())
    has_migrations = any(c["is_migration"] for c in classified.values())
    has_dependencies = any(c["is_dependency"] for c in classified.values())
    is_public_api_touched = any(c["is_public_api"] for c in classified.values())

    # Breaking candidate heuristic
    is_breaking_candidate = (
        has_migrations
        or has_dependencies
        or (is_public_api_touched and not has_openapi and not has_asyncapi)
    )

    potential_secrets = detect_secrets_in_diff(diff_text) if args.check_secrets and diff_text else False

    result = {
        "has_code": has_code,
        "has_tests": has_tests,
        "has_docs": has_docs,
        "has_openapi": has_openapi,
        "has_asyncapi": has_asyncapi,
        "has_infra": has_infra,
        "has_migrations": has_migrations,
        "has_dependencies": has_dependencies,
        "is_public_api_touched": is_public_api_touched,
        "is_breaking_candidate": is_breaking_candidate,
        "potential_secrets": potential_secrets,
        "size": estimate_size(lines_changed, files_changed),
        "lines_changed": lines_changed,
        "files_changed": files_changed,
        "languages": languages,
        "files": classified,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
