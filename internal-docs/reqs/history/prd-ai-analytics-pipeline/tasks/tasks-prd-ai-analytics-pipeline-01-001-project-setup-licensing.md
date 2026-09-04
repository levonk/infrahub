# ⚠️ DEPRECATED - Replaced by AI Dashboard

This task has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.

**Migration**: Use the ai-dashboard project for all analytics development.

---
story_id: "01-001"
story_title: "Project Setup and Licensing Framework"
story_name: "project-setup-licensing"
prd_name: "prd-ai-analytics-pipeline"
prd_file: "internal-docs/deprecated/prd-ai-analytics-pipeline.md"
phase: 1
parallel_id: 1
branch: "feature/current/prd-ai-analytics-pipeline/story-01-001-project-setup-licensing"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["project-root", "licensing"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "setup"]
due: "2025-01-20"
created_at: "2025-01-20"
updated_at: "2025-01-20"
---

## Summary

Initialize the project structure with proper licensing framework (AGPL 3.0), development environment setup, and foundational configuration files. This story establishes the project baseline for all subsequent development work.

## Sub-Tasks

- [x] Create project directory structure and basic files
- [x] Set up AGPL 3.0 license and LICENSE.md file
- [x] Create CONTRIBUTING.md with contribution guidelines
- [x] Set up README.md with project overview and quickstart
- [x] Create .gitignore for Python, JavaScript, and Docker
- [x] Set up basic Docker configuration (docker-compose.yml)
- [x] Create environment variable template (.env.example)
- [x] Set up project configuration files (config.yaml)
- [x] Create basic development scripts (Makefile or package.json scripts)
- [x] Set up basic project documentation structure

## Relevant Files

**Project: ~/p/gh/levonk/infrahub**
- `LICENSE.md` - AGPL 3.0 license file
- `CONTRIBUTING.md` - Contribution guidelines and CLA information
- `README.md` - Project overview, installation, and quickstart guide
- `.gitignore` - Git ignore patterns for Python, Docker
- `docker-compose.yml` - Docker orchestration for development
- `.env.example` - Environment variable template
- `config.yaml` - Main configuration file template
- `Makefile` - Development and build scripts
- `docs/` - Documentation directory structure

**Project: ~/p/gh/levonk/ai-dashboard**
- `LICENSE.md` - AGPL 3.0 license file
- `CONTRIBUTING.md` - Contribution guidelines
- `README.md` - Dashboard project overview
- `.gitignore` - Git ignore patterns for JavaScript, Docker
- `package.json` - Node.js dependencies and scripts
- `docs/` - Dashboard documentation

## Acceptance Criteria

- [x] Project directory structure follows Python best practices
- [x] AGPL 3.0 license properly applied with copyright notice
- [x] CONTRIBUTING.md includes CLA requirements for dual licensing
- [x] README.md provides clear installation and quickstart instructions
- [x] .gitignore covers all relevant file types and dependencies
- [x] docker-compose.yml can spin up basic development environment
- [x] .env.example documents all required environment variables
- [x] config.yaml includes all basic configuration options with comments
- [x] Development scripts work for common tasks (test, lint, build)
- [x] Documentation structure is established for future docs

## Test Plan

- Manual: Verify project structure matches Python project layout
- Manual: Test docker-compose up brings up development environment
- Manual: Verify all configuration files are valid YAML/JSON
- Manual: Test development scripts execute successfully

## Observability

- N/A for this foundational story

## Compliance

- AGPL 3.0 license compliance in all source files
- CLA process documented for future dual licensing
- No proprietary dependencies or code

## Risks & Mitigations

- Risk: License complexity may confuse contributors
  - Mitigation: Clear documentation in CONTRIBUTING.md and README
- Risk: Docker environment may not work on all platforms
  - Mitigation: Document platform-specific requirements and alternatives

## Dependencies

- None (foundational story)

## Notes

- This story establishes the legal and structural foundation for the project
- All subsequent stories depend on this foundational work
- Focus on simplicity and clarity for contributor onboarding