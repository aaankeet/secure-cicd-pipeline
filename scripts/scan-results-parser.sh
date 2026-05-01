#!/bin/bash

set -euo pipefail

echo "🔍 Parsing security scan results..."

# Check jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required"
  exit 1
fi

# ----------------------------
# Initialize report
# ----------------------------
comment="## 🛡️ Security Scan Results\n\n"

# --- Gitleaks Refinement ---
if [ -s "gitleaks-report.json" ] && [ "$(jq 'length' gitleaks-report.json)" -gt 0 ]; then
    leaks_count=$(jq 'length' gitleaks-report.json)
    comment+="### ❌ Secrets Found ($leaks_count)\n"
    comment+="| File | Line | Secret Type |\n| :--- | :--- | :--- |\n"

    # Extract top 10 leaks to avoid hitting PR comment character limits
    findings=$(jq -r '.[:10] | .[] | "| \(.File) | \(.StartLine) | \(.Description) |"' gitleaks-report.json)
    comment+="$findings\n\n"

    if [ "$leaks_count" -gt 10 ]; then
        comment+="*...and $((leaks_count - 10)) more findings. Check artifacts for full report.*\n\n"
    fi
else
    comment+="### ✅ Secrets\nNo hardcoded secrets detected.\n\n"
fi

# --- Semgrep Refinement ---
if [ -s "semgrep-results.sarif" ]; then
    critical=$(jq '[.runs[].results[]? | select(.level=="error")] | length' semgrep-results.sarif)
    if [ "$critical" -gt 0 ]; then
        comment+="### ❌ SAST Issues\nFound **$critical** critical vulnerabilities. Please check the 'Security' tab or uploaded SARIF report.\n\n"
    else
        comment+="### ✅ SAST\nNo critical vulnerabilities found.\n\n"
    fi
fi

# --- Post to PR ---
if [ -n "${PR_NUMBER:-}" ]; then
    echo "Posting to PR $PR_NUMBER..."
    payload=$(jq -n --arg body "$comment" '{body: $body}')
    curl -sS -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
      -d "$payload"
else
    echo -e "$comment"
fi
