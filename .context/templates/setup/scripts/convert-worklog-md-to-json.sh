#!/bin/bash

###############################################################################
# convert-worklog-md-to-json.sh
#
# Converts workflow_log.md (Markdown table) to workflow_log.json (structured JSON)
# Uses Python for robust parsing that handles special characters and escaping
# 
# Usage:
#   scripts/convert-worklog-md-to-json.sh
#
# Effects:
#   - Creates: docs/project_log/workflow_log.json
#   - Backs up: docs/project_log/workflow_log.md.backup.{timestamp}
#   - Validates: schema against .context/schemas/workflow_log_schema.json
#
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
WORKLOG_MD="docs/project_log/workflow_log.md"
WORKLOG_JSON="docs/project_log/workflow_log.json"
SCHEMA_FILE=".context/schemas/workflow_log_schema.json"
TIMESTAMP=$(date +%s)
BACKUP_FILE="docs/project_log/workflow_log.md.backup.${TIMESTAMP}"

# Check if source exists
if [ ! -f "$WORKLOG_MD" ]; then
    echo -e "${RED}❌ ERROR: $WORKLOG_MD not found${NC}"
    exit 1
fi

# Check if already migrated
if [ -f "$WORKLOG_JSON" ]; then
    echo -e "${YELLOW}⚠️  WARNING: $WORKLOG_JSON already exists${NC}"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Check dependencies
for cmd in jq python3; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ ERROR: Required command '$cmd' not found${NC}"
        exit 1
    fi
done

echo -e "${BLUE}📋 Converting workflow_log.md to workflow_log.json${NC}"

# Step 1-8: Python script handles parsing, conversion, validation
echo -e "${BLUE}Step 1: Parsing markdown table and building JSON...${NC}"

TEMP_JSON=$(python3 << 'PYTHON_EOF'
import json
import re
from datetime import datetime

MD_FILE = "docs/project_log/workflow_log.md"

entries = []
id_counters = {
    "SETUP": 0, "TDD": 0, "USR": 0, "BUG": 0, 
    "FEAT": 0, "HOTFIX": 0, "TASK": 0
}

# Read markdown file
with open(MD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Extract table rows
in_table = False
for i, line in enumerate(lines):
    # Skip until we find the data table start (skip header/instructions)
    # Detect table by counting pipes (data rows have 8+ pipes for 7 fields)
    if line.startswith("|") and len(line.split("|")) >= 8:
        in_table = True
    
    if in_table and line.startswith("|") and len(line.split("|")) >= 8:
        # Parse pipe-delimited row
        parts = [p.strip() for p in line.split("|")[1:-1]]  # Remove first/last empty
        
        if len(parts) >= 7:
            fecha, fase, usuario, accion, resultado, feature_id, obs = parts[:7]
            
            # Clean up values
            feature_id = feature_id if feature_id and feature_id != "null" else None
            obs = obs if obs and obs != "null" else None
            
            # Update counters (only for PREFIX-NNN format)
            if feature_id:
                match = re.match(r"([A-Z]+)-(\d+)", feature_id)
                if match:
                    prefix, num = match.groups()
                    num = int(num)
                    if prefix in id_counters:
                        id_counters[prefix] = max(id_counters[prefix], num)
                # Other formats (EPICA.01.1, etc.) are stored as-is without counter update
            
            entry = {
                "timestamp": fecha,
                "fase": fase,
                "usuario_agente": usuario,
                "accion": accion,
                "resultado": resultado,
                "feature_id": feature_id,
                "observaciones": obs
            }
            entries.append(entry)

# Build JSON structure
metadata = {
    "project_name": "myrmion-AI-factory",
    "created_at": "2026-02-04T00:00:00Z",
    "migrated_from_markdown": datetime.utcnow().isoformat() + "Z",
    "version": "1.0.0",
    "id_counters": id_counters,
    "statistics": {
        "total_entries": len(entries),
        "last_updated": datetime.utcnow().isoformat() + "Z",
        "entries_by_agent": {}
    }
}

# Calculate agent stats
for entry in entries:
    agent = entry["usuario_agente"]
    metadata["statistics"]["entries_by_agent"][agent] = \
        metadata["statistics"]["entries_by_agent"].get(agent, 0) + 1

worklog = {
    "metadata": metadata,
    "entries": entries
}

# Output JSON (pretty-printed)
print(json.dumps(worklog, indent=2, ensure_ascii=False))
PYTHON_EOF
)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ERROR: Python conversion failed${NC}"
    exit 1
fi

ENTRY_COUNT=$(echo "$TEMP_JSON" | jq '.entries | length')
echo -e "${GREEN}✓ Parsed $ENTRY_COUNT entries${NC}"

if [ "$ENTRY_COUNT" -lt 1 ]; then
    echo -e "${RED}❌ ERROR: No entries found${NC}"
    exit 1
fi

# Step 2: Validate JSON syntax
echo -e "${BLUE}Step 2: Validating JSON syntax...${NC}"

if ! echo "$TEMP_JSON" | jq empty 2>/dev/null; then
    echo -e "${RED}❌ ERROR: Generated JSON is invalid${NC}"
    echo "$TEMP_JSON" | head -50
    exit 1
fi
echo -e "${GREEN}✓ JSON syntax valid${NC}"

# Step 3: Validate required structure
echo -e "${BLUE}Step 3: Validating JSON structure...${NC}"

for field in "metadata" "entries"; do
    if ! echo "$TEMP_JSON" | jq -e ".${field}" > /dev/null 2>&1; then
        echo -e "${RED}❌ ERROR: Missing required field: $field${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ JSON structure valid${NC}"

# Step 3b: Real JSON Schema validation
echo -e "${BLUE}Step 3b: Validating against JSON Schema...${NC}"

if [ -f "$SCHEMA_FILE" ]; then
    # Create temp JSON file for validation
    TEMP_JSON_FILE=$(mktemp)
    echo "$TEMP_JSON" > "$TEMP_JSON_FILE"
    
    if python3 -m jsonschema -i "$TEMP_JSON_FILE" "$SCHEMA_FILE" 2>&1 > /tmp/schema_validation.log; then
        echo -e "${GREEN}✓ JSON Schema validation passed${NC}"
        rm -f "$TEMP_JSON_FILE"
    else
        echo -e "${RED}❌ ERROR: JSON Schema validation failed${NC}"
        cat /tmp/schema_validation.log
        rm -f "$TEMP_JSON_FILE"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  WARNING: Schema file not found - skipping schema validation${NC}"
fi

# Step 4: Create backup
echo -e "${BLUE}Step 4: Creating backup...${NC}"

cp "$WORKLOG_MD" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Step 5: Write JSON file
echo -e "${BLUE}Step 5: Writing workflow_log.json...${NC}"

echo "$TEMP_JSON" > "$WORKLOG_JSON"
chmod 644 "$WORKLOG_JSON"
echo -e "${GREEN}✓ File written${NC}"

# Step 6: Final validation
echo -e "${BLUE}Step 6: Final validation...${NC}"

if ! jq empty "$WORKLOG_JSON" 2>/dev/null; then
    echo -e "${RED}❌ ERROR: Generated file is invalid${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Final validation passed${NC}"

echo ""
echo -e "${GREEN}✅ Migration successful!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  • Source: $WORKLOG_MD"
echo "  • Destination: $WORKLOG_JSON"
echo "  • Entries migrated: $ENTRY_COUNT"
echo "  • Backup: $BACKUP_FILE"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  • View: jq . $WORKLOG_JSON | less"
echo "  • Dashboard: open scripts/worklog-dashboard.html"
echo "  • Validate: scripts/validate-worklog-json.sh"
echo "  • Search: scripts/view-worklog.sh --feature USR-001"
echo ""

exit 0
