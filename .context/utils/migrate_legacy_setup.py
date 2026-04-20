#!/usr/bin/env python3
"""
Version: 1.0.0
Purpose: Migrate legacy setup.md format to tripartite architecture
Usage: python migrate_legacy_setup.py --input docs/setup.md --output docs/setup_migrated.md
"""

import sys
import yaml
import argparse
from pathlib import Path
from datetime import datetime


# Migration mappings
BACKEND_TOPOLOGY_MAPPING = {
    "Modular Monolith": "Modular Monolith (Modular por Bounded Contexts)",
    "Microservices": "Microservices (REST puro)",
    "Serverless": "Serverless (AWS Lambda)",
    "SOA": "Microservices (SOA con ESB)",
}

FRONTEND_STRATEGY_MAPPING = {
    "SPA": "SPA (React/Vue/Angular)",
    "SSR": "SSR (Con hidratación)",
    "Jamstack": "Jamstack/SSG (Next.js/Gatsby)",
    "Micro-Frontends": "Micro-Frontends (Module Federation)",
}


def load_setup_md(filepath: Path) -> tuple:
    """Load setup.md and split frontmatter from content."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            frontmatter = yaml.safe_load(parts[1])
            markdown_content = parts[2].strip()
            return frontmatter, markdown_content
    
    return {}, content


def detect_legacy_format(frontmatter: dict) -> bool:
    """Detect if setup.md is in old format."""
    # Old format indicators:
    # - Missing ai_budget_tier
    # - Missing integration_strategy
    # - Backend/Frontend values without suffix patterns
    
    if 'ai_budget_tier' not in frontmatter:
        return True
    
    if 'integration_strategy' not in frontmatter:
        return True
    
    backend = frontmatter.get('backend_topology', '')
    if backend and '(' not in backend:  # Old format lacks parentheses
        return True
    
    return False


def migrate_frontmatter(old_frontmatter: dict) -> dict:
    """Migrate old frontmatter to new tripartite format."""
    new_frontmatter = old_frontmatter.copy()
    
    # Add AI Budget section
    if 'ai_budget_tier' not in new_frontmatter:
        # Default to Professional tier
        new_frontmatter['ai_budget_tier'] = 'Professional'
        new_frontmatter['monthly_budget_limit'] = 2000
        new_frontmatter['budget_tracking_enabled'] = True
    
    # Migrate backend topology
    if 'backend_topology' in new_frontmatter:
        old_value = new_frontmatter['backend_topology']
        if old_value in BACKEND_TOPOLOGY_MAPPING:
            new_frontmatter['backend_topology'] = BACKEND_TOPOLOGY_MAPPING[old_value]
    
    # Migrate frontend strategy
    if 'frontend_strategy' in new_frontmatter:
        old_value = new_frontmatter['frontend_strategy']
        if old_value in FRONTEND_STRATEGY_MAPPING:
            new_frontmatter['frontend_strategy'] = FRONTEND_STRATEGY_MAPPING[old_value]
    
    # Add Integration Strategy section
    if 'integration_strategy' not in new_frontmatter:
        new_frontmatter['integration_strategy'] = 'ACL Global (contract-first)'
        new_frontmatter['contract_tools'] = ['OpenAPI 3.1', 'JSON Schema']
    
    # Add brownfield_detected if missing
    if 'brownfield_detected' not in new_frontmatter:
        new_frontmatter['brownfield_detected'] = False
        new_frontmatter['extension_strategy'] = None
    
    # Normalize extension_strategy to new E0/E1/E2/E3 nomenclature
    ext_strategy = new_frontmatter.get('extension_strategy')
    EXTENSION_STRATEGY_MIGRATION = {
        'Preserve Current + Wrapper': 'E1',
        'Preserve+Wrapper': 'E1',
        'preserve_wrapper': 'E1',
        'Strangler Fig': 'E2',
        'strangler_fig': 'E2',
        'Full Rewrite': 'E3',
        'full_rewrite': 'E3',
    }
    if ext_strategy in EXTENSION_STRATEGY_MIGRATION:
        new_frontmatter['extension_strategy'] = EXTENSION_STRATEGY_MIGRATION[ext_strategy]
    # If extension_strategy is already E0/E1/E2/E3 or None, keep as-is
    
    # Add migration metadata
    new_frontmatter['migrated_from_legacy'] = True
    new_frontmatter['migration_date'] = datetime.now().isoformat()
    new_frontmatter['last_update'] = datetime.now().isoformat()
    
    # Update phase if DISCOVERY completed
    if new_frontmatter.get('discovery_completed', False):
        new_frontmatter['phase'] = 'PLANNING'
    
    return new_frontmatter


def add_missing_sections(markdown_content: str, frontmatter: dict) -> str:
    """Add missing sections to markdown content."""
    sections_to_add = []
    
    # Check if AI Budget section exists
    if '## 🤖 AI Budget Configuration' not in markdown_content:
        tier = frontmatter.get('ai_budget_tier', 'Professional')
        limit = frontmatter.get('monthly_budget_limit', 2000)
        
        sections_to_add.append(f"""
## 🤖 AI Budget Configuration

**Tier:** {tier}  
**Monthly Limit:** ${limit:,} USD/mes  
**Tracking:** {'Enabled' if frontmatter.get('budget_tracking_enabled', True) else 'Disabled'}  

**Cost Breakdown:**
- Backend: TBD (after /SETUP --generate)
- Frontend: TBD
- Integrations: TBD
- Total: TBD

**Tracking File:** `.claude/rules/ai_budget_tracker.instructions.md`
""")
    
    # Check if Integration Strategy section exists
    if '## 🔌 Integration Strategy' not in markdown_content:
        strategy = frontmatter.get('integration_strategy', 'ACL Global (contract-first)')
        tools = frontmatter.get('contract_tools', ['OpenAPI 3.1'])
        
        sections_to_add.append(f"""
## 🔌 Integration Strategy

**Approach:** {strategy}  
**Contract Tools:** {', '.join(tools)}  
**Validation:** JSON Schema required for all contracts  

**ACL Pattern:**
- All third-party integrations wrapped in `src/integration/acl/`
- Contract-first development (contracts defined before implementation)
- Integration tests validate contract compliance
""")
    
    # Append new sections before "## Decision Log" if it exists
    if sections_to_add:
        if '## Decision Log' in markdown_content:
            parts = markdown_content.split('## Decision Log')
            updated_content = parts[0] + '\n'.join(sections_to_add) + '\n\n## Decision Log' + parts[1]
        else:
            updated_content = markdown_content + '\n' + '\n'.join(sections_to_add)
        
        return updated_content
    
    return markdown_content


def save_migrated_setup(filepath: Path, frontmatter: dict, markdown_content: str):
    """Save migrated setup.md."""
    frontmatter_yaml = yaml.dump(frontmatter, default_flow_style=False, allow_unicode=True)
    
    full_content = f"""---
{frontmatter_yaml}---

{markdown_content}
"""
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(full_content)


def migrate(input_path: Path, output_path: Path) -> bool:
    """Main migration function."""
    if not input_path.exists():
        print(f"❌ Error: {input_path} not found")
        return False
    
    # Load existing setup.md
    frontmatter, markdown_content = load_setup_md(input_path)
    
    # Detect if migration needed
    is_legacy = detect_legacy_format(frontmatter)
    
    if not is_legacy:
        print("ℹ️ Setup.md is already in new format. No migration needed.")
        return True
    
    print("\n" + "=" * 70)
    print("🔄 MIGRATING LEGACY SETUP.MD")
    print("=" * 70)
    
    # Migrate frontmatter
    new_frontmatter = migrate_frontmatter(frontmatter)
    
    # Add missing sections
    updated_markdown = add_missing_sections(markdown_content, new_frontmatter)
    
    # Save migrated file
    save_migrated_setup(output_path, new_frontmatter, updated_markdown)
    
    print("\n**Changes Applied:**")
    
    # Report changes
    if 'ai_budget_tier' not in frontmatter:
        print("  ✅ Added AI Budget section (default: Professional tier)")
    
    if 'integration_strategy' not in frontmatter:
        print("  ✅ Added Integration Strategy section (ACL Global)")
    
    if frontmatter.get('backend_topology') != new_frontmatter.get('backend_topology'):
        print(f"  ✅ Migrated Backend: {frontmatter.get('backend_topology')} → {new_frontmatter.get('backend_topology')}")
    
    if frontmatter.get('frontend_strategy') != new_frontmatter.get('frontend_strategy'):
        print(f"  ✅ Migrated Frontend: {frontmatter.get('frontend_strategy')} → {new_frontmatter.get('frontend_strategy')}")
    
    print(f"  ✅ Added metadata: migrated_from_legacy=true, migration_date={new_frontmatter['migration_date']}")
    
    print(f"\n✅ Migration complete! Saved to: {output_path}")
    print("\n⚠️ **Next Steps:**")
    print("   1. Review migrated file for accuracy")
    print("   2. Run `/SETUP --generate` to materialize tripartite architecture")
    print("   3. Backup original file if needed")
    print("\n" + "=" * 70)
    
    return True


def main():
    parser = argparse.ArgumentParser(description='Migrate legacy setup.md to tripartite architecture format')
    parser.add_argument('--input', type=str, required=True, help='Path to legacy setup.md')
    parser.add_argument('--output', type=str, required=True, help='Path for migrated setup.md')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    output_path = Path(args.output)
    
    success = migrate(input_path, output_path)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
