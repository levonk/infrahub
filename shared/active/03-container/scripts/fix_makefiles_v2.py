import os
import re

ROOT_DIR = "/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet"

def fix_makefile(path):
    rel = os.path.relpath(path, ROOT_DIR)
    depth = rel.count("/")
    proj_dir = "/".join([".."] * depth)

    with open(path, "r") as f:
        content = f.read()

    # 1. Surgical fix for COMPOSE_FILE corruption
    lines = content.splitlines()
    new_lines = []

    sub_dir_path = os.path.dirname(path)
    sub_dir_name = os.path.basename(sub_dir_path)
    files_in_dir = os.listdir(sub_dir_path)
    compose_files = [f for f in files_in_dir if f.startswith("docker-compose") and f.endswith(".yml")]

    for line in lines:
        if line.startswith("COMPOSE_FILE :="):
            if "ENV_FILE" in line or "--project-directory" in line or "docker compose" in line or "docker-compose " in line:
                if compose_files:
                    matches = [f for f in compose_files if sub_dir_name in f]
                    best_file = matches[0] if matches else compose_files[0]
                    if "../docker-compose" in line:
                        line = f"COMPOSE_FILE := ../{best_file}"
                    else:
                        line = f"COMPOSE_FILE := {best_file}"
                else:
                    line = re.sub(r"\s*--project-directory\s+\$\(PROJECT_DIR\)", "", line)
                    line = re.sub(r"docker compose\s+", "", line)
                    line = re.sub(r"docker-compose\s+", "", line)
            new_lines.append(line)
            continue

        if line.startswith("PROJECT_DIR :="):
            continue

        line = re.sub(r"--project-directory\s+[^\s]+\s*", "", line)

        if line.strip().startswith("COMPOSE :=") or line.startswith("\t"):
            line = re.sub(r"\bdocker\s+compose\b", "docker compose --project-directory $(PROJECT_DIR)", line)
            line = re.sub(r"\bdocker-compose\b", "docker-compose --project-directory $(PROJECT_DIR)", line)

        if "$(ENSURE_NETWORK)" in line and "--project-directory" not in line:
            line = line.replace("$(ENSURE_NETWORK)", "$(ENSURE_NETWORK) --project-directory $(PROJECT_DIR)")

        line = line.replace("--project-directory $(PROJECT_DIR) --project-directory $(PROJECT_DIR)", "--project-directory $(PROJECT_DIR)")
        new_lines.append(line)

    insert_idx = 0
    for i, line in enumerate(new_lines):
        if line.startswith(".PHONY") or line.startswith("COMPOSE_FILE :="):
            insert_idx = i
            break
        if not line.startswith("#") and line.strip():
            insert_idx = i
            break

    new_lines.insert(insert_idx, f"PROJECT_DIR := {proj_dir}")

    with open(path, "w") as f:
        f.write("\n".join(new_lines) + "\n")
    print(f"Fixed {path}")

def main():
    services_root = os.path.join(ROOT_DIR, "services")
    for root, dirs, files in os.walk(services_root):
        if "Makefile" in files:
            fix_makefile(os.path.join(root, "Makefile"))

if __name__ == "__main__":
    main()
