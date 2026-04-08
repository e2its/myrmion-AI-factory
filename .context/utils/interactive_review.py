#!/usr/bin/env python3
"""
Version: 1.0.0
Purpose: Interactive Discovery phase confirmation UI
Usage: python interactive_review.py docs/setup.md
"""

import sys
import yaml
from pathlib import Path
from datetime import datetime
from typing import Dict, Any


def load_setup_md(setup_path: Path) -> Dict[str, Any]:
    """Load and parse setup.md YAML frontmatter and content."""
    with open(setup_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract YAML frontmatter
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            frontmatter = yaml.safe_load(parts[1])
            body = parts[2]
            return {**frontmatter, '_body': body}
    
    return {}


def save_setup_md(setup_path: Path, data: Dict[str, Any]):
    """Save setup.md with updated frontmatter."""
    body = data.pop('_body', '')
    
    with open(setup_path, 'w', encoding='utf-8') as f:
        f.write('---\n')
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
        f.write('---\n')
        f.write(body)


def display_summary(data: Dict[str, Any]):
    """Display formatted decision summary."""
    print("\n" + "═" * 70)
    print("📋 RESUMEN DE DECISIONES - FASE DISCOVERY")
    print("═" * 70)
    
    print("\n## 🎯 Contexto del Proyecto")
    print("┌" + "─" * 68 + "┐")
    print(f"│ Objetivo:    {data.get('goal', 'N/A'):<54} │")
    print(f"│ Modo:        {data.get('mode', 'N/A'):<54} │")
    print(f"│ Lenguaje:    {data.get('language', 'N/A'):<54} │")
    print(f"│ Deployment:  {data.get('deployment', 'N/A'):<54} │")
    print("└" + "─" * 68 + "┘")
    
    print("\n## 💰 Presupuesto IA")
    print("┌" + "─" * 68 + "┐")
    print(f"│ Tier:           {data.get('ai_budget_tier', 'N/A'):<49} │")
    print(f"│ Límite Mensual: ${data.get('monthly_budget_limit', 0):<48} USD/mes │")
    print(f"│ Tracking:       {'Enabled' if data.get('budget_tracking') else 'Disabled':<49} │")
    print("└" + "─" * 68 + "┘")
    
    if data.get('mode') == 'BROWNFIELD':
        print("\n## 🔍 Estado Actual (BROWNFIELD)")
        print("┌" + "─" * 68 + "┐")
        current_state = data.get('current_state', {})
        backend = current_state.get('detected_backend', {})
        frontend = current_state.get('detected_frontend', {})
        
        print(f"│ Backend Detectado:                                                 │")
        print(f"│   - Framework:  {backend.get('framework', 'N/A'):<49} │")
        print(f"│   - Patrón:     {backend.get('pattern', 'N/A'):<49} │")
        print(f"│   - Deployment: {backend.get('deployment', 'TBD'):<49} │")
        print(f"│                                                                    │")
        print(f"│ Frontend Detectado:                                                │")
        print(f"│   - Framework:  {frontend.get('framework', 'N/A'):<49} │")
        print(f"│   - UX:         {frontend.get('ux_strategy', 'N/A'):<49} │")
        print(f"│   - Patrón:     {frontend.get('pattern', 'N/A'):<49} │")
        print(f"│                                                                    │")
        
        integrations = current_state.get('detected_integrations', [])
        print(f"│ Integraciones: {', '.join(integrations) if integrations else 'None':<50} │")
        print("└" + "─" * 68 + "┘")
    
    print("\n" + "═" * 70)


def modify_section(data: Dict[str, Any]) -> bool:
    """Handle modification of specific section."""
    print("\n📝 MODO MODIFICACIÓN")
    print("\nSelecciona la sección a modificar:")
    print("[1] Contexto del Proyecto")
    print("[2] Presupuesto IA")
    
    if data.get('mode') == 'BROWNFIELD':
        print("[3] Estado Actual Brownfield")
    
    print("[0] Volver al resumen\n")
    
    choice = input("Ingresa el número: ").strip()
    
    if choice == '1':
        print("\n🎯 MODIFICAR CONTEXTO")
        data['goal'] = input(f"Objetivo [{data.get('goal', '')}]: ") or data.get('goal')
        data['language'] = input(f"Lenguaje [{data.get('language', '')}]: ") or data.get('language')
        data['deployment'] = input(f"Deployment [{data.get('deployment', '')}]: ") or data.get('deployment')
        return True
        
    elif choice == '2':
        print("\n💰 MODIFICAR PRESUPUESTO IA")
        print("1. Starter (<$500/mes)")
        print("2. Professional ($500-$2,000/mes)")
        print("3. Enterprise ($2,000-$10,000/mes)")
        print("4. Unlimited (>$10,000/mes)")
        print("[X] Mantener actual\n")
        
        tier_choice = input("Selecciona [1-4, X]: ").strip()
        tier_map = {
            '1': ('Starter', 500),
            '2': ('Professional', 2000),
            '3': ('Enterprise', 10000),
            '4': ('Unlimited', float('inf'))
        }
        
        if tier_choice in tier_map:
            data['ai_budget_tier'], data['monthly_budget_limit'] = tier_map[tier_choice]
            print(f"✅ Actualizado a: {data['ai_budget_tier']}")
            return True
            
    elif choice == '3' and data.get('mode') == 'BROWNFIELD':
        print("\n🔍 MODIFICAR ESTADO BROWNFIELD")
        print("(Nota: Detectado automáticamente. Solo modificar si incorrecto)")
        return True
        
    elif choice == '0':
        return False
    
    return False


def interactive_review_loop(setup_path: Path):
    """Main interactive review loop."""
    data = load_setup_md(setup_path)
    
    while True:
        display_summary(data)
        
        print("\n❓ ¿Deseas confirmar estas decisiones y continuar?\n")
        print("Opciones:")
        print("[C] Confirmar y continuar a Planning Phase")
        print("[M] Modificar alguna decisión")
        print("[R] Revisar setup.md en detalle")
        print("[X] Cancelar setup\n")
        
        choice = input("Ingresa tu opción [C/M/R/X]: ").strip().upper()
        
        if choice == 'C':
            # Confirm and transition
            data['phase'] = 'PLANNING'
            data['discovery_completed'] = True
            data['discovery_confirmed_at'] = datetime.now().isoformat()
            data['user_confirmed'] = True
            
            save_setup_md(setup_path, data)
            
            print("\n✅ DECISIONES CONFIRMADAS")
            print("\nGuardando configuración final en docs/setup.md...")
            print("\nActualizando frontmatter:")
            print("  phase: DISCOVERY → PLANNING")
            print("  discovery_completed: true")
            print(f"  last_update: {data['discovery_confirmed_at']}")
            print("\n" + "═" * 70)
            print("🎉 DISCOVERY PHASE COMPLETADA")
            print("\nPróximos pasos:")
            print("1. Ejecuta `/SETUP --plan` para generar roadmap de decisiones")
            print("2. O ejecuta `/BLUEPRINT --review-setup` para validación previa\n")
            
            return True
            
        elif choice == 'M':
            # Modification loop
            if modify_section(data):
                save_setup_md(setup_path, data)
                print("\n✅ Cambios guardados. Regenerando resumen...")
            
        elif choice == 'R':
            # Show full content
            print("\n📖 REVISIÓN DETALLADA")
            print("─" * 70)
            with open(setup_path, 'r', encoding='utf-8') as f:
                print(f.read())
            print("─" * 70)
            input("\nPresiona ENTER para volver al resumen...")
            
        elif choice == 'X':
            # Cancel setup
            print("\n⚠️ CANCELAR SETUP")
            confirm = input("¿Estás seguro? [Y/N]: ").strip().upper()
            
            if confirm == 'Y':
                data['status'] = 'CANCELLED'
                data['cancelled_at'] = datetime.now().isoformat()
                data['cancelled_reason'] = 'User requested cancellation during Discovery review'
                
                save_setup_md(setup_path, data)
                
                print("\n❌ SETUP CANCELADO")
                print("\nPara reiniciar el setup:")
                print("1. Elimina docs/setup.md")
                print("2. Ejecuta /SETUP --init nuevamente\n")
                
                return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python interactive_review.py docs/setup.md")
        sys.exit(1)
    
    setup_path = Path(sys.argv[1])
    
    if not setup_path.exists():
        print(f"❌ Error: {setup_path} not found")
        sys.exit(1)
    
    interactive_review_loop(setup_path)


if __name__ == '__main__':
    main()
