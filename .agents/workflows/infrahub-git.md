- Run the skill ~/p/gh/levonk/dotfiles/home/current/.chezmoitemplates/config/ai/skills/software-dev/git-repository-management/SKILL.md 
- on the infrahub project and all the client submodules

## CRITICAL: Submodule Handling Rules

**NEVER** convert git submodules to regular directories. This destroys the intended architecture and can expose sensitive information.

### Submodule Workflow

**When working with client submodules (e.g., levonk/):**

1. **NEVER** delete the submodule and replace it with a regular directory
2. **NEVER** treat submodule files as if they were part of the parent repo
3. **ALWAYS** use proper git submodule commands:
   ```bash
   # Update submodule to latest
   git submodule update --remote levonk
   
   # Enter submodule to make changes
   cd levonk
   # Make changes, commit, push
   git add .
   git commit -m "Description"
   git push origin master
   
   # Return to parent and update reference
   cd ..
   git add levonk
   git commit -m "Update levonk submodule reference"
   ```

4. **ALWAYS** work within the submodule directory for submodule-specific changes
5. **NEVER** modify submodule files from the parent repo without entering the submodule first

### Client Submodule Security

**CRITICAL**: Client submodules contain PRIVATE CLIENT-SPECIFIC INFORMATION:

- **✅ CORRECT**: Secrets in `levonk/active/02-config/ansible/group_vars/infrahub-levonk-all.vault.yml`
- **❌ FORBIDDEN**: Secrets in parent repo's `shared/` directory
- **❌ FORBIDDEN**: Converting submodule to regular directory (breaks isolation)
- **❌ FORBIDDEN**: Moving secrets from submodule to shared/ directory

Each client submodule has its own `AGENTS.md` with specific rules. Always read the submodule's AGENTS.md before making changes.

### Detection of Submodule Issues

**WARNING SIGNS** that a submodule has been incorrectly converted:
- Submodule directory contains `.gitignore` file (shouldn't exist in submodule)
- `git status` shows submodule as "modified" with no staged changes
- Submodule files appear as regular files instead of submodule reference
- `.gitmodules` file has been modified to remove submodule entry

**IMMEDIATE REMEDIATION** if detected:
1. Revert the destructive commit
2. Restore proper git submodule structure
3. Commit the fix immediately
4. Review for any exposed sensitive information