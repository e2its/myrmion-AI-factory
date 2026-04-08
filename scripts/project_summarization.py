import os
import argparse

def count_lines_dynamic(target_path):
    ignore_dirs = {'.git', '__pycache__', 'node_modules', 'venv', '.ipynb_checkpoints'}
    
    # Diccionario dinámico: { 'nombre_carpeta': total_lineas }
    stats = {}
    total_general = 0

    target_path = os.path.abspath(target_path)

    if not os.path.isdir(target_path):
        print(f"Error: '{target_path}' no es un directorio.")
        return

    for root, dirs, files in os.walk(target_path):
        # Evitar carpetas ocultas/ignoradas
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        # Determinar la categoría basada en el primer nivel de profundidad
        relative_path = os.path.relpath(root, target_path)
        
        if relative_path == ".":
            category = "Raíz del Proyecto"
        else:
            # Tomamos solo el nombre de la carpeta de primer nivel
            category = relative_path.split(os.sep)[0]

        if category not in stats:
            stats[category] = 0

        for file in files:
            file_path = os.path.join(root, file)
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    # Contamos líneas no vacías
                    lines = sum(1 for line in f if line.strip())
                    stats[category] += lines
                    total_general += lines
            except (UnicodeDecodeError, PermissionError):
                continue

    # Mostrar resultados
    print(f"\nAnálisis dinámico de ruta: {target_path}")
    print(f"{'-' * 45}")
    print(f"{'DIRECTORIO / CATEGORÍA':<25} | {'LÍNEAS':<10}")
    print(f"{'-' * 45}")
    
    # Ordenar por volumen de líneas (de mayor a menor)
    for cat, count in sorted(stats.items(), key=lambda item: item[1], reverse=True):
        if count > 0:
            print(f"{cat[:25]:<25} | {count:<10}")
            
    print(f"{'-' * 45}")
    print(f"{'TOTAL GENERAL':<25} | {total_general:<10}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Contador dinámico de líneas por estructura de carpetas.")
    parser.add_argument("ruta", nargs="?", default=".", help="Ruta a analizar (ej: ../)")
    
    args = parser.parse_args()
    count_lines_dynamic(args.ruta)