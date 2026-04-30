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

# ----------------------------
# Gitleaks (Secrets)
# ----------------------------
if [ -f "gitleaks-report.json" ]; then
  leaks=$(jq 'length' gitleaks-report.json 2>/dev/null || echo 0)

  if [ "$leaks" -gt 0 ]; then
    comment+="❌ **Secrets**: $leaks found\n\n"
  else
    comment+="✅ **Secrets**: No issues\n\n"
  fi
else
  comment+="⚠️ **Secrets**: No report found\n\n"
fi

# ----------------------------
# Semgrep (SAST)
# ----------------------------
if [ -f "semgrep-results.sarif" ]; then
  critical=$(jq '[.runs[].results[]? | select(.level=="error")] | length' semgrep-results.sarif 2>/dev/null || echo 0)

  if [ "$critical" -gt 0 ]; then
    comment+="❌ **SAST**: $critical critical issues\n\n"
  else
    comment+="✅ **SAST**: No critical issues\n\n"
  fi
else
  comment+="⚠️ **SAST**: No report found\n\n"
fi

# ----------------------------
# Output result
# ----------------------------
echo -e "$comment"

# ----------------------------
# Post comment to PR
# ----------------------------
if [ -n "${PR_NUMBER:-}" ]; then
  echo "📢 Posting comment to PR #$PR_NUMBER"

  curl --max-time 10 -s \
       -H "Authorization: token $GITHUB_TOKEN" \
       -H "Content-Type: application/json" \
       -X POST \
       "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
       -d "$(jq -n --arg body "$comment" '{body: $body}')"
else
  echo "⚠️ Not a PR run, skipping comment"
fi
