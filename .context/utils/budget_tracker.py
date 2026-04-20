#!/usr/bin/env python3
"""
Version: 1.0.0
Purpose: Track AI token consumption per feature and enforce monthly budget limits
Usage: python budget_tracker.py --feature FEAT-001 --tokens 12500 --operation log|check|reset
"""

import sys
import yaml
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any


TRACKER_FILE = Path('.claude/rules/ai_budget_tracker.instructions.md')


def ensure_tracker_exists():
    """Create tracker file if it doesn't exist."""
    if TRACKER_FILE.exists():
        return
    
    TRACKER_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    initial_content = """# AI Budget Tracker

**Monthly Limit:** $2,000 USD  
**Current Month:** {current_month}  
**Total Consumed:** $0.00 (0% of budget)  
**Remaining:** $2,000.00  
**Status:** 🟢 Healthy  

---

## Token Conversion Rate
- **GPT-4 Turbo:** $0.01 / 1K tokens (input), $0.03 / 1K tokens (output)
- **Claude 3.5 Sonnet:** $0.003 / 1K tokens (input), $0.015 / 1K tokens (output)
- **Average Blended Rate:** $0.015 / 1K tokens (conservative estimate)

---

## Feature-Level Consumption

| Feature ID | Date | Tokens Used | Cost (USD) | Phase | Status |
|-----------|------|-------------|------------|-------|--------|
| - | - | - | - | - | - |

---

## Monthly History

### {current_month}
- **Total Tokens:** 0
- **Total Cost:** $0.00
- **Features Completed:** 0

---

## Alerts & Warnings

**None**

---

## Auto-Reset

This tracker resets automatically on the 1st of each month.  
Last reset: {current_date}
""".format(
        current_month=datetime.now().strftime('%Y-%m'),
        current_date=datetime.now().strftime('%Y-%m-%d')
    )
    
    TRACKER_FILE.write_text(initial_content, encoding='utf-8')
    print(f"✅ Created tracker file: {TRACKER_FILE}")


def parse_tracker() -> Dict[str, Any]:
    """Parse existing tracker file."""
    content = TRACKER_FILE.read_text(encoding='utf-8')
    
    data = {
        'monthly_limit': 2000.0,
        'total_consumed': 0.0,
        'current_month': datetime.now().strftime('%Y-%m'),
        'features': [],
    }
    
    # Extract monthly limit
    if '**Monthly Limit:**' in content:
        limit_line = [line for line in content.split('\n') if '**Monthly Limit:**' in line][0]
        limit_str = limit_line.split('$')[1].split()[0].replace(',', '')
        data['monthly_limit'] = float(limit_str)
    
    # Extract total consumed
    if '**Total Consumed:**' in content:
        consumed_line = [line for line in content.split('\n') if '**Total Consumed:**' in line][0]
        consumed_str = consumed_line.split('$')[1].split()[0]
        data['total_consumed'] = float(consumed_str)
    
    # Extract current month
    if '**Current Month:**' in content:
        month_line = [line for line in content.split('\n') if '**Current Month:**' in line][0]
        data['current_month'] = month_line.split('**Current Month:**')[1].strip()
    
    # Parse feature table
    table_started = False
    for line in content.split('\n'):
        if line.startswith('| Feature ID'):
            table_started = True
            continue
        if line.startswith('|---'):
            continue
        if table_started and line.startswith('| ') and '| - | - | - |' not in line:
            parts = [p.strip() for p in line.split('|')[1:-1]]
            if len(parts) >= 6:
                feature_id, date, tokens, cost, phase, status = parts[:6]
                if feature_id != '-':
                    data['features'].append({
                        'id': feature_id,
                        'date': date,
                        'tokens': int(tokens.replace(',', '')) if tokens != '-' else 0,
                        'cost': float(cost.replace('$', '').replace(',', '')) if cost != '-' else 0.0,
                        'phase': phase,
                        'status': status,
                    })
        elif table_started and not line.startswith('|'):
            break
    
    return data


def calculate_cost(tokens: int, blended_rate: float = 0.015) -> float:
    """Calculate cost from tokens (default: $0.015 per 1K tokens)."""
    return (tokens / 1000) * blended_rate


def log_feature_usage(feature_id: str, tokens: int, phase: str = 'Implementation'):
    """Log token usage for a feature."""
    ensure_tracker_exists()
    
    data = parse_tracker()
    
    # Check if month changed (auto-reset)
    current_month = datetime.now().strftime('%Y-%m')
    if data['current_month'] != current_month:
        print(f"🔄 Month changed ({data['current_month']} → {current_month}). Resetting tracker...")
        reset_tracker()
        data = parse_tracker()
    
    # Calculate cost
    cost = calculate_cost(tokens)
    new_total = data['total_consumed'] + cost
    
    # Check budget limit
    utilization = (new_total / data['monthly_limit']) * 100
    
    if new_total > data['monthly_limit']:
        print(f"\n❌ **BUDGET EXCEEDED!**")
        print(f"   Feature: {feature_id} (+${cost:.2f})")
        print(f"   New Total: ${new_total:.2f} (>${data['monthly_limit']:.2f} limit)")
        print(f"   **Action Required:** Pause feature development or request budget increase")
        return False
    
    # Add feature entry
    data['features'].append({
        'id': feature_id,
        'date': datetime.now().strftime('%Y-%m-%d'),
        'tokens': tokens,
        'cost': cost,
        'phase': phase,
        'status': '🟢 Active',
    })
    
    data['total_consumed'] = new_total
    
    # Write updated tracker
    write_tracker(data, utilization)
    
    print(f"\n✅ **Logged:** {feature_id}")
    print(f"   Tokens: {tokens:,} → ${cost:.2f}")
    print(f"   Total: ${new_total:.2f} / ${data['monthly_limit']:,.0f} ({utilization:.1f}%)")
    
    if utilization >= 80:
        print(f"\n⚠️ **Warning:** Budget utilization ≥80%")
    
    return True


def check_budget() -> bool:
    """Check current budget status."""
    ensure_tracker_exists()
    data = parse_tracker()
    
    utilization = (data['total_consumed'] / data['monthly_limit']) * 100
    remaining = data['monthly_limit'] - data['total_consumed']
    
    print("\n" + "=" * 70)
    print("💰 BUDGET STATUS")
    print("=" * 70)
    print(f"**Month:** {data['current_month']}")
    print(f"**Limit:** ${data['monthly_limit']:,.2f}")
    print(f"**Consumed:** ${data['total_consumed']:.2f} ({utilization:.1f}%)")
    print(f"**Remaining:** ${remaining:.2f}")
    
    if utilization < 50:
        print(f"**Status:** 🟢 Healthy")
    elif utilization < 80:
        print(f"**Status:** 🟡 Caution")
    elif utilization < 100:
        print(f"**Status:** 🟠 Warning")
    else:
        print(f"**Status:** 🔴 Exceeded")
    
    print("\n**Features Tracked:** " + str(len(data['features'])))
    print("=" * 70 + "\n")
    
    return utilization < 100


def reset_tracker():
    """Reset tracker for new month."""
    ensure_tracker_exists()
    data = parse_tracker()
    
    # Archive current month
    archive_month = data['current_month']
    total_tokens = sum(f['tokens'] for f in data['features'])
    total_cost = data['total_consumed']
    num_features = len(data['features'])
    
    # Reset data
    data['current_month'] = datetime.now().strftime('%Y-%m')
    data['total_consumed'] = 0.0
    archived_features = data['features'].copy()
    data['features'] = []
    
    # Write reset tracker with archived history
    write_tracker(data, 0.0, archived_features, archive_month, total_tokens, total_cost, num_features)
    
    print(f"\n✅ Tracker reset for new month: {data['current_month']}")
    print(f"   Archived {archive_month}: {num_features} features, ${total_cost:.2f} total")


def write_tracker(data: Dict[str, Any], utilization: float, 
                  archived_features=None, archive_month=None, 
                  archive_tokens=0, archive_cost=0.0, archive_num=0):
    """Write updated tracker file."""
    
    remaining = data['monthly_limit'] - data['total_consumed']
    
    if utilization < 50:
        status = '🟢 Healthy'
    elif utilization < 80:
        status = '🟡 Caution'
    elif utilization < 100:
        status = '🟠 Warning'
    else:
        status = '🔴 Exceeded'
    
    # Build feature table
    feature_rows = ""
    if data['features']:
        for f in data['features']:
            feature_rows += f"| {f['id']} | {f['date']} | {f['tokens']:,} | ${f['cost']:.2f} | {f['phase']} | {f['status']} |\n"
    else:
        feature_rows = "| - | - | - | - | - | - |\n"
    
    # Build alerts
    alerts = "**None**"
    if utilization >= 80:
        alerts = f"""
⚠️ **Budget utilization ≥80%**  
- Consider:
  - Upgrade to higher tier
  - Review architecture complexity
  - Defer non-critical features
"""
    
    # Build archived history
    archived_section = ""
    if archived_features and archive_month:
        archived_section = f"""
### {archive_month}
- **Total Tokens:** {archive_tokens:,}
- **Total Cost:** ${archive_cost:.2f}
- **Features Completed:** {archive_num}

**Archived Features:**

| Feature ID | Date | Tokens | Cost | Phase | Status |
|-----------|------|--------|------|-------|--------|
"""
        for f in archived_features:
            archived_section += f"| {f['id']} | {f['date']} | {f['tokens']:,} | ${f['cost']:.2f} | {f['phase']} | {f['status']} |\n"
        
        archived_section += "\n---\n"
    
    content = f"""# AI Budget Tracker

**Monthly Limit:** ${data['monthly_limit']:,.2f} USD  
**Current Month:** {data['current_month']}  
**Total Consumed:** ${data['total_consumed']:.2f} ({utilization:.1f}% of budget)  
**Remaining:** ${remaining:.2f}  
**Status:** {status}  

---

## Token Conversion Rate
- **GPT-4 Turbo:** $0.01 / 1K tokens (input), $0.03 / 1K tokens (output)
- **Claude 3.5 Sonnet:** $0.003 / 1K tokens (input), $0.015 / 1K tokens (output)
- **Average Blended Rate:** $0.015 / 1K tokens (conservative estimate)

---

## Feature-Level Consumption

| Feature ID | Date | Tokens Used | Cost (USD) | Phase | Status |
|-----------|------|-------------|------------|-------|--------|
{feature_rows}
---

## Monthly History

{archived_section}
### {data['current_month']}
- **Total Tokens:** {sum(f['tokens'] for f in data['features']):,}
- **Total Cost:** ${data['total_consumed']:.2f}
- **Features Completed:** {len(data['features'])}

---

## Alerts & Warnings

{alerts}

---

## Auto-Reset

This tracker resets automatically on the 1st of each month.  
Last reset: {datetime.now().strftime('%Y-%m-%d')}
"""
    
    TRACKER_FILE.write_text(content, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description='Track AI token consumption')
    parser.add_argument('--feature', type=str, help='Feature ID (e.g., FEAT-001)')
    parser.add_argument('--tokens', type=int, help='Number of tokens consumed')
    parser.add_argument('--phase', type=str, default='Implementation', help='Development phase')
    parser.add_argument('--operation', type=str, choices=['log', 'check', 'reset'], required=True,
                       help='Operation to perform')
    
    args = parser.parse_args()
    
    if args.operation == 'log':
        if not args.feature or not args.tokens:
            print("❌ Error: --feature and --tokens required for log operation")
            sys.exit(1)
        success = log_feature_usage(args.feature, args.tokens, args.phase)
        sys.exit(0 if success else 1)
    
    elif args.operation == 'check':
        within_budget = check_budget()
        sys.exit(0 if within_budget else 1)
    
    elif args.operation == 'reset':
        reset_tracker()
        sys.exit(0)


if __name__ == '__main__':
    main()
