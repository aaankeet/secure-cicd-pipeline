#!/bin/bash

set -euo pipefail

echo "🔍 Parsing security scan results..."

# ----------------------------
# Check dependencies
# ----------------------------
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed"
  exit 1
fi

# ----------------------------
# Initialize report
# ----------------------------
comment="## 🛡️ Security Scan Results\n\n"
comment+="> Branch: \`${GITHUB_HEAD_REF:-unknown}\` | Run: [#${GITHUB_RUN_NUMBER:-?}](https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0})\n\n"
comment+="---\n\n"

overall_status="pass"

# ----------------------------
# Gitleaks (Secrets Detection)
# ----------------------------
comment+="### 🔑 Secrets Detection (Gitleaks)\n\n"

if [ -f "gitleaks-report.json" ]; then
  leaks=$(jq 'length' gitleaks-report.json 2>/dev/null || echo 0)

  if [ "$leaks" -gt 0 ]; then
    overall_status="fail"
    comment+="❌ **$leaks secret(s) found**\n\n"
    comment+="| # | Rule | File | Line | Fingerprint |\n"
    comment+="|---|------|------|------|-------------|\n"

    # Build table rows for each finding
    while IFS= read -r row; do
      rule=$(echo "$row"   | jq -r '.RuleID   // "unknown"')
      file=$(echo "$row"   | jq -r '.File     // "unknown"')
      line=$(echo "$row"   | jq -r '.StartLine // "?"')
      fp=$(echo "$row"     | jq -r '.Fingerprint // "N/A"')
      short_fp="${fp:0:16}..."

      comment+="| 🔴 | \`$rule\` | \`$file\` | $line | \`$short_fp\` |\n"
    done < <(jq -c '.[]' gitleaks-report.json 2>/dev/null)

    comment+="\n> ⚠️ Secrets have been **redacted** in this report. Rotate any exposed credentials immediately.\n\n"
  else
    comment+="✅ **No secrets detected**\n\n"
  fi

else
  comment+="⚠️ **Gitleaks report not found** — scan may not have run\n\n"
fi

comment+="---\n\n"

# ----------------------------
# Semgrep (SAST)
# ----------------------------
comment+="### 🔬 Static Analysis (Semgrep)\n\n"

if [ -f "semgrep-results.sarif" ]; then

  # Count ALL findings (not just level=="error" — community rules often emit "warning" in SARIF even when blocking)
  total=$(jq '[.runs[].results[]?] | length' semgrep-results.sarif 2>/dev/null || echo 0)

  # Separate by level
  errors=$(jq '[.runs[].results[]? | select(.level=="error")] | length'   semgrep-results.sarif 2>/dev/null || echo 0)
  warnings=$(jq '[.runs[].results[]? | select(.level=="warning")] | length' semgrep-results.sarif 2>/dev/null || echo 0)
  notes=$(jq '[.runs[].results[]? | select(.level=="note")] | length'     semgrep-results.sarif 2>/dev/null || echo 0)

  if [ "$total" -gt 0 ]; then
    # Only fail the pipeline on errors, not warnings
    if [ "$errors" -gt 0 ]; then
      overall_status="fail"
      comment+="❌ **$total finding(s)** — $errors error(s), $warnings warning(s), $notes note(s)\n\n"
    else
      comment+="⚠️ **$total finding(s)** — $errors error(s), $warnings warning(s), $notes note(s)\n\n"
    fi

    comment+="| # | Rule ID | Severity | File | Line | Message |\n"
    comment+="|---|---------|----------|------|------|---------|\n"

    while IFS= read -r row; do
      rule_id=$(echo "$row" | jq -r '.ruleId // "unknown"')
      level=$(echo "$row"   | jq -r '.level  // "unknown"')
      file=$(echo "$row"    | jq -r '.locations[0].physicalLocation.artifactLocation.uri // "unknown"')
      line=$(echo "$row"    | jq -r '.locations[0].physicalLocation.region.startLine    // "?"')
      msg=$(echo "$row"     | jq -r '.message.text // "No message"' | cut -c1-60)

      # Pick icon based on level
      case "$level" in
        error)   icon="🔴" ;;
        warning) icon="🟡" ;;
        note)    icon="🔵" ;;
        *)       icon="⚪" ;;
      esac

      comment+="| $icon | \`$rule_id\` | $level | \`$file\` | $line | $msg |\n"
    done < <(jq -c '.runs[].results[]?' semgrep-results.sarif 2>/dev/null)

    comment+="\n"
  else
    comment+="✅ **No findings detected**\n\n"
  fi

else
  comment+="⚠️ **Semgrep report not found** — scan may not have run\n\n"
fi

comment+="---\n\n"

# ----------------------------
# Overall Status Footer
# ----------------------------
if [ "$overall_status" = "fail" ]; then
  comment+="### 🚨 Overall Status: FAILED\n\n"
  comment+="> One or more security checks failed. **Do not merge** until all findings are resolved or formally excepted.\n"
else
  comment+="### ✅ Overall Status: PASSED\n\n"
  comment+="> All security checks passed. Safe to review for merge.\n"
fi

# ----------------------------
# Print to console
# ----------------------------
echo -e "$comment"

# ----------------------------
# Post comment to PR
# ----------------------------
if [ -n "${PR_NUMBER:-}" ]; then
  echo "📢 Posting comment to PR #$PR_NUMBER..."

  HTTP_STATUS=$(curl --max-time 15 -s -o /tmp/gh_response.json -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -d "$(jq -n --arg body "$(echo -e "$comment")" '{body: $body}')")

  if [ "$HTTP_STATUS" = "201" ]; then
    echo "✅ Comment posted successfully"
  else
    echo "❌ Failed to post comment (HTTP $HTTP_STATUS)"
    cat /tmp/gh_response.json
    exit 1
  fi
else
  echo "⚠️ PR_NUMBER not set — skipping GitHub comment"
fi
