---
id: l-improvement-001
title: Create AI Development Loop automation scripts for LocalNet
status: open
deps: []
links: []
created: 2026-03-25T15:41:00Z
type: improvement
priority: high
description: Create dev-loop-helper.sh and orchestrator.sh scripts to automate AI Development Loop steps for LocalNet project
---

# Create AI Development Loop automation scripts for LocalNet

Based on assessment from ticket l-11ebc2b4, create automation scripts to streamline AI agent workflow:

## Scripts to Create

### 1. scripts/dev-loop-helper.sh
- Foundation check with environment validation
- Ticket selection and management (tkr integration)
- Automated verification steps
- Quality gate validation

### 2. scripts/orchestrator.sh  
- End-to-end AI Development Loop execution
- Step-by-step guidance with verbose output
- Error handling and recovery
- Integration with LocalNet environment

### 3. scripts/git-repo-manager.sh
- Organized commit management
- Branch cleanup and verification
- Integration with ticket system

## Requirements

- Use Devbox environment wrapping
- Integrate with tkr ticket management
- Support LocalNet profile-based service management
- Include security scanning in foundation checks
- Provide verbose logging for debugging
- Handle error recovery gracefully
