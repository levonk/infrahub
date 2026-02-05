import os
import re

ROOT_DIR = "/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet"

def fix_makefile(path):
    rel = os.path.relpath(path, ROOT_DIR)
    depth = rel.count('/')
    proj_dir = '/'.join(['..'] * depth)

    with open(path, 'r') as f:
        content = f.read()

    # 1. Surgical fix for COMPOSE_FILE corruption
    # Pattern: COMPOSE_FILE := ... something ... ENV_FILE := ...
    # We need to extract the actual compose file name.
    # Usually it is docker-compose.<service>.yml or docker-compose.yml
    lines = content.splitlines()
    new_lines = []

    for line in lines:
        if line.startswith('COMPOSE_FILE :='):
            # Check for corruption pattern
            if 'ENV_FILE' in line:
                # Try to recover the filename
                compose_files = [f for f in files_in_dir if f.startswith('docker-compose') and f.endswith('.yml')]

                if compose_files:
                    # Pick the one that contains the sub_dir_name if multiple exist
                    matches = [f for f in compose_files if sub_dir_name in f]
                    best_file = matches[0] if matches else compose_files[0]
                    # Check if it was originally pointing to a parent dir (common in gost/traefik/tor)
                    if '../docker-compose' in line:
                        line = f"COMPOSE_FILE := ../{best_file}\n"
                    else:
                        line = f"COMPOSE_FILE := {best_file}\n"
                else:
                    # Fallback: remove the flag and keep the rest
                    line = re.sub(r'\s*--project-directory\s+\$\(PROJECT_DIR\)', '', line)
                    line = re.sub(r'docker compose', 'docker-compose', line)
                    line = re.sub(r'docker-compose\.', 'docker-compose.', line)

            new_lines.append(line)
            continue

        # 3. Clean up existing flags in all lines to avoid duplication
        line = re.sub(r'--project-directory\s+\$\(PROJECT_DIR\)\s*', '', line)
        line = re.sub(r'--project-directory\s+\.\.[^ ]*\s*', '', line)

        # 4. Add flag to docker commands (indented or in COMPOSE :=)
        if line.strip().startswith('COMPOSE :=') or line.startswith('\t'):
            line = re.sub(r'\bdocker\s+compose\b', 'docker compose --project-directory $(PROJECT_DIR)', line)
            line = re.sub(r'\bdocker-compose\b', 'docker-compose --project-directory $(PROJECT_DIR)', line)

        # 5. Handle ENSURE_NETWORK usage
        if '$(ENSURE_NETWORK)' in line and '--project-directory' not in line:
            line = line.replace('$(ENSURE_NETWORK)', '$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR)')

        # Final safety check: remove double flags
        line = line.replace('--project-directory $(PROJECT_DIR) --project-directory $(PROJECT_DIR)', '--project-directory $(PROJECT_DIR)')

        new_lines.append(line)

    # Find insertion point for PROJECT_DIR
    insert_idx = 0
    for i, line in enumerate(new_lines):
        if line.startswith('.PHONY') or line.startswith('COMPOSE_FILE :='):
            insert_idx = i
            break

    new_lines.insert(insert_idx, f"PROJECT_DIR := {proj_dir}\n")

    with open(path, 'w') as f:
        f.writelines(new_lines)
    print(f"Fixed {path}")

def main():
    services_root = os.path.join(ROOT_DIR, "services")
    for root, dirs, files in os.walk(services_root):
        for filename in files:
            if filename == "Makefile":
                fix_makefile(os.path.join(root, filename))

if __name__ == "__main__":
    main()
