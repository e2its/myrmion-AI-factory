#!/usr/bin/env python3
"""
Version: 1.0.0
Purpose: Validate total cost against AI budget tier
Usage: python budget_validator.py --setup docs/setup.md
"""

import sys
import yaml
import argparse
from pathlib import Path
from typing import Dict, Any, List, Tuple


# Cost configuration (USD/month)
BACKEND_COSTS = {
    "Modular Monolith (Tradicional)": 180,
    "Modular Monolith (Modular por Bounded Contexts)": 300,
    "Modular Monolith (DDD con Event Sourcing)": 450,
    "Modular Monolith (Microkernel con Plugins)": 480,
    "Microservices (REST puro)": 800,
    "Microservices (Event-Driven)": 1100,
    "Microservices (CQRS + Event Sourcing)": 1300,
    "Microservices (SOA con ESB)": 700,
    "Serverless (AWS Lambda)": 400,
    "Serverless (Azure Functions)": 400,
    "Serverless (Google Cloud Functions)": 400,
    "Serverless (Cloudflare Workers)": 400,
    "Peer-to-Peer": 900,
    "Broker/Pipeline (RabbitMQ)": 650,
    "Broker/Pipeline (Apache Kafka)": 650,
    "Broker/Pipeline (Azure Service Bus)": 650,
}

FRONTEND_COSTS = {
    "SPA": 100,
    "SSR (Con hidratación)": 150,
    "SSR (Sin hidratación puro)": 120,
    "Micro-Frontends (Module Federation)": 400,
    "Micro-Frontends (iFrames)": 400,
    "Micro-Frontends (Web Components)": 400,
    "Jamstack/SSG": 80,
    "Islands Architecture (Astro)": 200,
    "Islands Architecture (Qwik)": 200,
}

STATE_MANAGEMENT_COSTS = {
    "Redux": 50,
    "Zustand": 50,
    "Jotai": 50,
    "Context API": 0,
    "Nano Stores": 0,
    "None": 0,
}

COMPLEXITY_MULTIPLIERS = {
    "Low": 1.0,
    "Medium": 1.3,
    "High": 1.8,
}

BUDGET_TIERS = {
    "Starter": {"min": 0, "max": 500},
    "Professional": {"min": 500, "max": 2000},
    "Enterprise": {"min": 2000, "max": 10000},
    "Unlimited": {"min": 10000, "max": float('inf')},
}


def load_setup_md(setup_path: Path) -> Dict[str, Any]:
    """Load setup.md and extract decisions."""
    with open(setup_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            return yaml.safe_load(parts[1])
    
    return {}


def calculate_total_cost(data: Dict[str, Any]) -> Tuple[float, Dict[str, float]]:
    """Calculate total monthly cost breakdown."""
    breakdown = {}
    
    # Backend cost
    backend_topology = data.get('backend_topology', '')
    backend_cost = BACKEND_COSTS.get(backend_topology, 0)
    breakdown['backend_base'] = backend_cost
    
    # Frontend cost
    frontend_strategy = data.get('frontend_strategy', '')
    frontend_cost = FRONTEND_COSTS.get(frontend_strategy, 0)
    breakdown['frontend_base'] = frontend_cost
    
    # State management cost
    state_management = data.get('state_management', 'None')
    state_cost = STATE_MANAGEMENT_COSTS.get(state_management, 0)
    breakdown['state_management'] = state_cost
    
    # Integration ACL costs
    num_integrations = data.get('num_integrations', 0)
    acl_cost = num_integrations * 50  # $50 per ACL
    breakdown['integration_acls'] = acl_cost
    
    # Backend Aggregator (if distributed backend)
    backend_aggregator_cost = 0
    if any(keyword in backend_topology for keyword in ['Microservices', 'SOA', 'Broker']):
        backend_aggregator_cost = 100
    breakdown['backend_aggregator'] = backend_aggregator_cost
    
    # Subtotal before complexity
    subtotal = sum(breakdown.values())
    breakdown['subtotal'] = subtotal
    
    # Complexity multiplier
    complexity = data.get('complexity', 'Medium')
    multiplier = COMPLEXITY_MULTIPLIERS.get(complexity, 1.3)
    breakdown['complexity_multiplier'] = multiplier
    
    # Total cost
    total = subtotal * multiplier
    breakdown['total'] = total
    
    return total, breakdown


def generate_alternatives(data: Dict[str, Any], current_total: float, budget_limit: float) -> List[Dict[str, Any]]:
    """Generate alternative configurations within budget."""
    alternatives = []
    
    backend_topology = data.get('backend_topology', '')
    frontend_strategy = data.get('frontend_strategy', '')
    
    # Option A: Simplify Backend
    if 'Event-Driven' in backend_topology or 'CQRS' in backend_topology:
        alt_backend = "Microservices (REST puro)"
        alt_data = {**data, 'backend_topology': alt_backend, 'complexity': 'Medium'}
        alt_total, _ = calculate_total_cost(alt_data)
        
        if alt_total <= budget_limit:
            alternatives.append({
                'label': 'Opción A - Simplificar Backend',
                'changes': f"Backend: {backend_topology} → {alt_backend}",
                'total': alt_total,
                'savings': current_total - alt_total
            })
    
    # Option B: Simplify Frontend
    if 'Micro-frontends' in frontend_strategy:
        alt_frontend = "SSR (Con hidratación)"
        alt_data = {**data, 'frontend_strategy': alt_frontend, 'state_management': 'Context API', 'complexity': 'Medium'}
        alt_total, _ = calculate_total_cost(alt_data)
        
        if alt_total <= budget_limit:
            alternatives.append({
                'label': 'Opción B - Simplificar Frontend',
                'changes': f"Frontend: {frontend_strategy} → {alt_frontend}, State: Context API",
                'total': alt_total,
                'savings': current_total - alt_total
            })
    
    # Option C: Reduce integrations
    num_integrations = data.get('num_integrations', 0)
    if num_integrations > 4:
        alt_integrations = num_integrations // 2
        alt_data = {**data, 'num_integrations': alt_integrations}
        alt_total, _ = calculate_total_cost(alt_data)
        
        if alt_total <= budget_limit:
            alternatives.append({
                'label': 'Opción C - Reducir integraciones',
                'changes': f"ACLs: {num_integrations} → {alt_integrations}",
                'total': alt_total,
                'savings': current_total - alt_total
            })
    
    return alternatives


def validate_budget(setup_path: Path) -> bool:
    """Main validation function."""
    data = load_setup_md(setup_path)
    
    ai_budget_tier = data.get('ai_budget_tier', 'Professional')
    monthly_budget_limit = data.get('monthly_budget_limit', 2000)
    
    total_cost, breakdown = calculate_total_cost(data)
    
    print("\n" + "=" * 70)
    print("💰 VALIDACIÓN DE PRESUPUESTO")
    print("=" * 70)
    
    print(f"\n**Budget Tier:** {ai_budget_tier} (${monthly_budget_limit:,} USD/mes)")
    
    print("\n**Configuración Seleccionada:**")
    print(f"- Backend: {data.get('backend_topology', 'N/A')} → ${breakdown['backend_base']:.0f}")
    print(f"- Frontend: {data.get('frontend_strategy', 'N/A')} → ${breakdown['frontend_base']:.0f}")
    print(f"- State Management: {data.get('state_management', 'None')} → ${breakdown['state_management']:.0f}")
    print(f"- Integraciones: {data.get('num_integrations', 0)} ACLs → ${breakdown['integration_acls']:.0f}")
    print(f"- Backend Aggregator: ${breakdown['backend_aggregator']:.0f}")
    print(f"- Complexity Multiplier: {data.get('complexity', 'Medium')} ({breakdown['complexity_multiplier']}x)")
    print(f"- **SUBTOTAL:** ${breakdown['subtotal']:.0f} × {breakdown['complexity_multiplier']} = **${total_cost:.0f}/mes**")
    
    within_budget = total_cost <= monthly_budget_limit
    
    if within_budget:
        utilization = (total_cost / monthly_budget_limit) * 100
        print(f"\n✅ **Budget Status:** Within Budget ({utilization:.1f}% utilization)")
        
        if utilization >= 80:
            print("\n⚠️ **Warning:** Budget utilization ≥80%. Consider:")
            print("   - Enterprise tier upgrade for headroom")
            print("   - Review architecture complexity")
        
        return True
    else:
        excess = total_cost - monthly_budget_limit
        excess_pct = (excess / monthly_budget_limit) * 100
        
        print(f"\n❌ **Budget Status:** Exceeds Budget")
        print(f"   **Exceso:** +${excess:.0f} (+{excess_pct:.1f}%)")
        
        print("\n---")
        print("\n**Alternativas Viables (dentro de presupuesto):**\n")
        
        alternatives = generate_alternatives(data, total_cost, monthly_budget_limit)
        
        if alternatives:
            for alt in alternatives:
                status = "✅" if alt['total'] <= monthly_budget_limit else "⚠️"
                print(f"{status} **{alt['label']} (${alt['total']:.0f}/mes)**")
                print(f"   - {alt['changes']}")
                print(f"   - **Ahorro:** ${alt['savings']:.0f}\n")
        else:
            print("**Opción D - Upgrade a tier superior**")
            print(f"   - Budget limit: ${monthly_budget_limit:,} → $10,000/mes (Enterprise)")
            print("   - Sin cambios arquitectónicos necesarios")
            print("   - Tracking estricto y auditoría avanzada requeridos\n")
        
        print("=" * 70)
        print("\n❓ **¿Cuál opción prefieres?**")
        print("Type [A], [B], [C], [D], or [custom] para ajustes personalizados\n")
        
        return False


def main():
    parser = argparse.ArgumentParser(description='Validate AI budget for setup configuration')
    parser.add_argument('--setup', type=str, required=True, help='Path to setup.md file')
    
    args = parser.parse_args()
    setup_path = Path(args.setup)
    
    if not setup_path.exists():
        print(f"❌ Error: {setup_path} not found")
        sys.exit(1)
    
    is_valid = validate_budget(setup_path)
    sys.exit(0 if is_valid else 1)


if __name__ == '__main__':
    main()
