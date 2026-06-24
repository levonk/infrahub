- Run the skill ~/p/gh/levonk/dotfiles/home/current/.chezmoitemplates/config/ai/skills/software-dev/git-repository-management/SKILL.md 
- on the infrahub project and all the client submodules

## CRITICAL: Read AGENTS.md Before Proceeding

**Before running this workflow, you MUST read the AGENTS.md file in the repository root.**

AGENTS.md contains critical rules about:
- Submodule handling (NEVER convert submodules to regular directories)
- Secret storage locations (per ADR-20260624001)
- Security requirements and ADR compliance
- Client-specific isolation requirements

**Each client submodule (e.g., levonk/) also has its own AGENTS.md with client-specific rules.**

Failure to follow these rules can result in:
- Exposed sensitive information
- Broken architecture
- Security violations
- Loss of client isolation