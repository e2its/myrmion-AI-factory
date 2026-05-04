#!/usr/bin/env python3
"""
post_review.py — Publishes a structured review on the PR's platform.

Supports GitHub (via gh CLI), GitLab (via glab CLI), and Azure DevOps (via az CLI).
Auto-detects the platform from the URL or remote.

Usage:
    python post_review.py --review review.json --pr-url https://github.com/owner/repo/pull/123
    python post_review.py --review review.json --pr-url ... --decision approve|request-changes|comment
    python post_review.py --review review.json --pr-url ... --dry-run

The review.json file must follow the structure defined in assets/review_template.md.

IMPORTANT: this script must NOT run without explicit user confirmation.
An incorrect review on a public platform stays public and notifies the author.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


def detect_platform(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if "github.com" in host:
        return "github"
    if "gitlab.com" in host or "gitlab" in host:
        return "gitlab"
    if "dev.azure.com" in host or "visualstudio.com" in host:
        return "azure"
    if "bitbucket.org" in host:
        return "bitbucket"
    return "unknown"


def parse_github_url(url: str):
    # https://github.com/owner/repo/pull/123
    m = re.match(r"https?://github\.com/([^/]+)/([^/]+)/pull/(\d+)", url)
    if not m:
        raise ValueError(f"Invalid GitHub URL: {url}")
    return m.group(1), m.group(2), int(m.group(3))


def render_review_markdown(review: dict) -> str:
    """Generates the review body in Markdown from the structured JSON."""
    parts = []

    # Header with summary
    parts.append(f"## Summary\n\n{review.get('summary', '_(no summary)_')}\n")

    # Verdict
    decision = review.get("decision", "comment")
    decision_label = {
        "approve": "✅ Approved",
        "request-changes": "🔴 Changes requested",
        "comment": "💬 Comments without verdict",
    }.get(decision, decision)
    parts.append(f"**Verdict:** {decision_label}\n")

    # Blockers
    if review.get("blockers"):
        parts.append("## 🔴 Blockers\n")
        for f in review["blockers"]:
            parts.append(f"### [{f.get('category', 'General')}] {f.get('issue', '')}\n")
            if f.get("file"):
                line = f.get("line", "")
                line_str = f":{line}" if line else ""
                parts.append(f"**File:** `{f['file']}{line_str}`\n")
            if f.get("code_snippet"):
                parts.append(f"```\n{f['code_snippet']}\n```\n")
            if f.get("details"):
                parts.append(f"**Why:** {f['details']}\n")
            if f.get("fix"):
                parts.append(f"**Suggested fix:** {f['fix']}\n")
            parts.append("")

    # Important
    if review.get("important"):
        parts.append("## 🟡 Important\n")
        for f in review["important"]:
            line = f":{f['line']}" if f.get("line") else ""
            file_part = f"`{f['file']}{line}` — " if f.get("file") else ""
            parts.append(f"- {file_part}{f.get('issue', '')}")
            if f.get("fix"):
                parts.append(f"  - _Suggested fix:_ {f['fix']}")
        parts.append("")

    # Nits
    if review.get("nits"):
        parts.append("## 🟢 Nits\n")
        for f in review["nits"]:
            line = f":{f['line']}" if f.get("line") else ""
            file_part = f"`{f['file']}{line}` — " if f.get("file") else ""
            parts.append(f"- {file_part}{f.get('issue', '')}")
        parts.append("")

    # Questions
    if review.get("questions"):
        parts.append("## ❓ Questions\n")
        for q in review["questions"]:
            parts.append(f"- {q}")
        parts.append("")

    # Praise
    if review.get("praise"):
        parts.append("## 👏 Praise\n")
        for p in review["praise"]:
            parts.append(f"- {p}")
        parts.append("")

    # Documentation checklist
    if review.get("docs_checklist"):
        parts.append("## 📋 Documentation checklist\n")
        for item, status in review["docs_checklist"].items():
            mark = {"ok": "x", "missing": " ", "n/a": "N/A"}.get(status, " ")
            parts.append(f"- [{mark}] {item}")
        parts.append("")

    # Mitigations applied during review (only when non-empty)
    if review.get("mitigations_applied"):
        parts.append("## 🔧 Mitigations applied during review\n")
        parts.append("The reviewer applied the following hot-fixes to the PR branch during the audit. Each entry resolves a finding above; the original finding entry is kept for traceability. Author retains the option to revert.\n")
        for m in review["mitigations_applied"]:
            ref = m.get("finding_ref", "(unscoped)")
            cat = m.get("category", "")
            cat_part = f" [{cat}]" if cat else ""
            parts.append(f"### {ref}{cat_part}\n")
            sha = m.get("commit_sha", "")
            sha_short = sha[:8] if sha else "?"
            branch = m.get("branch", "?")
            parts.append(f"**Commit:** `{sha_short}` on `{branch}`")
            if m.get("applied_at"):
                parts.append(f"**Applied at:** {m['applied_at']}")
            if m.get("description"):
                parts.append(f"**What was done:** {m['description']}")
            if m.get("verified_by"):
                parts.append(f"**Verified by:** {m['verified_by']}")
            parts.append("")

    # Footer with metadata
    parts.append("---")
    parts.append(f"_Review generated by pr-review skill — {review.get('generated_at', '')}_")

    return "\n".join(parts)


def post_to_github(review: dict, pr_url: str, decision: str, dry_run: bool):
    owner, repo, pr_number = parse_github_url(pr_url)
    body = render_review_markdown(review)

    if dry_run:
        print("=== DRY RUN — not publishing ===")
        print(f"Platform: GitHub")
        print(f"Owner/Repo: {owner}/{repo}")
        print(f"PR: #{pr_number}")
        print(f"Decision: {decision}")
        print()
        print(body)
        return

    # Validate gh CLI
    try:
        subprocess.run(["gh", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ERROR: gh CLI is not installed or authenticated.", file=sys.stderr)
        sys.exit(2)

    # Map decision
    gh_decision = {
        "approve": "--approve",
        "request-changes": "--request-changes",
        "comment": "--comment",
    }.get(decision, "--comment")

    # Publish
    cmd = [
        "gh", "pr", "review", str(pr_number),
        "--repo", f"{owner}/{repo}",
        gh_decision,
        "--body", body,
    ]

    print(f"Publishing review on {owner}/{repo}#{pr_number}...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR while publishing: {result.stderr}", file=sys.stderr)
        sys.exit(2)
    print("✓ Review published.")


def post_to_gitlab(review: dict, pr_url: str, decision: str, dry_run: bool):
    body = render_review_markdown(review)
    if dry_run:
        print("=== DRY RUN GitLab ===")
        print(body)
        return

    # glab CLI
    try:
        subprocess.run(["glab", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ERROR: glab CLI is not installed.", file=sys.stderr)
        sys.exit(2)

    # Extract MR id from URL
    m = re.match(r"https?://[^/]+/(.+)/-/merge_requests/(\d+)", pr_url)
    if not m:
        print("ERROR: GitLab URL not recognized.", file=sys.stderr)
        sys.exit(2)
    project, mr_id = m.group(1), m.group(2)

    cmd = ["glab", "mr", "note", mr_id, "--repo", project, "--message", body]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR: {result.stderr}", file=sys.stderr)
        sys.exit(2)
    print("✓ Comment published on GitLab.")

    # Approval / changes requested (if applicable)
    if decision == "approve":
        subprocess.run(["glab", "mr", "approve", mr_id, "--repo", project])


def post_to_azure(review: dict, pr_url: str, decision: str, dry_run: bool):
    """Stub for Azure DevOps. Requires `az` CLI with the devops extension."""
    body = render_review_markdown(review)
    if dry_run:
        print("=== DRY RUN Azure DevOps ===")
        print(body)
        return
    print("Publishing to Azure DevOps not implemented in this version. "
          "Use the generated template manually.", file=sys.stderr)
    print(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--review", type=Path, required=True, help="JSON file with the review")
    parser.add_argument("--pr-url", required=True, help="PR/MR URL")
    parser.add_argument("--decision", choices=["approve", "request-changes", "comment"], default="comment")
    parser.add_argument("--dry-run", action="store_true", help="Don't publish, just print")
    args = parser.parse_args()

    review = json.loads(args.review.read_text(encoding="utf-8"))
    platform = detect_platform(args.pr_url)

    if platform == "github":
        post_to_github(review, args.pr_url, args.decision, args.dry_run)
    elif platform == "gitlab":
        post_to_gitlab(review, args.pr_url, args.decision, args.dry_run)
    elif platform == "azure":
        post_to_azure(review, args.pr_url, args.decision, args.dry_run)
    else:
        print(f"Unsupported platform: {platform}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
