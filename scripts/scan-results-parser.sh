#!/bin/bash
set -euo pipefail

echo "🔍 Parsing security scan results..."

# Check jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required"
  exit 1
fi

# ----------------------------
# Initialize report (REAL newlines)
# ----------------------------
comment="## 🛡️ Security Scan Results"$'\n\n'

# ----------------------------
# Gitleaks (Secrets - CLI style)
# ----------------------------
if [ -s "gitleaks-report.json" ]; then
  leaks=$(jq 'length' gitleaks-report.json)

  if [ "$leaks" -gt 0 ]; then
    comment+="❌ Secrets Found ($leaks)"$'\n\n'

    findings=$(jq -r '.[:10][] |
"Finding: \(.Match)
Secret: REDACTED
RuleID: \(.RuleID)
Entropy: \(.Entropy)
File: \(.File)
Line: \(.StartLine)
Fingerprint: \(.Fingerprint)
"' gitleaks-report.json)

    comment+="$findings"$'\n'

    if [ "$leaks" -gt 10 ]; then
      comment+=$'\n'"...and $((leaks - 10)) more findings. Check artifacts."$'\n'
    fi

  else
    comment+="✅ No secrets detected"$'\n\n'
  fi
else
  comment+="⚠️ No Gitleaks report found"$'\n\n'
fi

# ----------------------------
# Semgrep (SAST)
# ----------------------------
if [ -s "semgrep-results.sarif" ]; then
  critical=$(jq '[.runs[].results[]? | select(.level=="error")] | length' semgrep-results.sarif)

  if [ "$critical" -gt 0 ]; then
    comment+=$'\n'"❌ SAST: $critical critical issues detected"$'\n'
  else
    comment+=$'\n'"✅ SAST: No critical vulnerabilities"$'\n'
  fi
else
  comment+=$'\n'"⚠️ No Semgrep report found"$'\n'
fi

# ----------------------------
# Output
# ----------------------------
echo "$comment"

# ----------------------------
# Post to PR
# ----------------------------
if [ -n "${PR_NUMBER:-}" ]; then
  echo "📢 Posting comment to PR #$PR_NUMBER"

  payload=$(jq -n --arg body "$comment" '{body: $body}')

  curl -sS -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -d "$payload"
else
  echo "⚠️ Not a PR run, skipping comment"
fi
