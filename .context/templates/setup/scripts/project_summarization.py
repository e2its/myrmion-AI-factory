import os
import argparse

def count_lines_dynamic(target_path):
    ignore_dirs = {'.git', '__pycache__', 'node_modules', 'venv', '.ipynb_checkpoints'}
    
    # Dynamic dictionary: { 'folder_name': total_lines }
    stats = {}
    total_general = 0

    target_path = os.path.abspath(target_path)

    if not os.path.isdir(target_path):
        print(f"Error: '{target_path}' is not a directory.")
        return

    for root, dirs, files in os.walk(target_path):
        # Skip hidden/ignored folders
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        # Determine the category based on the first depth level
        relative_path = os.path.relpath(root, target_path)
        
        if relative_path == ".":
            category = "Project Root"
        else:
            # Take only the first-level folder name
            category = relative_path.split(os.sep)[0]

        if category not in stats:
            stats[category] = 0

        for file in files:
            file_path = os.path.join(root, file)
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    # Count non-empty lines
                    lines = sum(1 for line in f if line.strip())
                    stats[category] += lines
                    total_general += lines
            except (UnicodeDecodeError, PermissionError):
                continue

    # Display results
    print(f"\nDynamic path analysis: {target_path}")
    print(f"{'-' * 45}")
    print(f"{'DIRECTORY / CATEGORY':<25} | {'LINES':<10}")
    print(f"{'-' * 45}")
    
    # Sort by line volume (highest to lowest)
    for cat, count in sorted(stats.items(), key=lambda item: item[1], reverse=True):
        if count > 0:
            print(f"{cat[:25]:<25} | {count:<10}")
            
    print(f"{'-' * 45}")
    print(f"{'GRAND TOTAL':<25} | {total_general:<10}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dynamic line counter by folder structure.")
    parser.add_argument("ruta", nargs="?", default=".", help="Path to analyze (e.g.: ../)")    
    
    args = parser.parse_args()
    count_lines_dynamic(args.ruta)