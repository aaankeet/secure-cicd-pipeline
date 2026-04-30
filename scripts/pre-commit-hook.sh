#!/bin/bash
#Pre-commit Hook for Scanning Secrets, Tokens, Api Keys & Passwords.

echo "🔒 Running pre-commit security checks..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ----------------------------
# 1. Gitleaks
# ----------------------------
if command -v gitleaks &> /dev/null; then
    echo -e "${YELLOW}Running Gitleaks...${NC}"

    if ! gitleaks detect --source . --verbose --redact; then
        echo -e "${RED}🚫 Secrets detected by Gitleaks!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Gitleaks not installed. Skipping...${NC}"
fi

# ----------------------------
# 2. TruffleHog
# ----------------------------
if command -v trufflehog &> /dev/null; then
    echo -e "${YELLOW}Running TruffleHog...${NC}"

    if ! trufflehog filesystem --directory terraform; then
        echo -e "${RED}🚫 Secrets detected by TruffleHog!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}TruffleHog not installed. Skipping...${NC}"
fi

# ----------------------------
# 3. Terraform Validation
# ----------------------------
if [ -d "terraform" ]; then
    echo -e "${YELLOW}Running Terraform validation...${NC}"

    if command -v terraform &> /dev/null; then
        terraform init -backend=false > /dev/null 2>&1

        if ! terraform validate; then
            echo -e "${RED}🚫 Terraform validation failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Terraform not installed. Skipping...${NC}"
    fi
fi

# ----------------------------
# 4. Basic Pattern-Based Secret Detection
# ----------------------------
files=$(find . -type f \
    ! -path "./policies/*" \
    ! -path "./scripts/*" \
    ! -path "./.github/*")

echo -e "${YELLOW}Checking for common secret patterns...${NC}"

forbidden_patterns=(
    "AKIA[0-9A-Z]{16}"
    "password[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "(secret|token)[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
)
found=false
for pattern in "${forbidden_patterns[@]}"; do
    if grep -iEr "$pattern" $files > /dev/null; then
         echo "🚫 Possible secret detected (pattern: $pattern)"
         grep -iErn "$pattern" $files
         found=true
    fi
    done
    if [ "$found" = true ]; then
        exit 1
    fi


# ----------------------------
# SUCCESS
# ----------------------------
echo -e "${GREEN}✅ All checks passed!${NC}"
exit 0
