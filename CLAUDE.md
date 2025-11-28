# CLAUDE.md - AI Assistant Guide for lua Repository

## Repository Overview

This is the `lua` repository owned by `kekhazkft-code`. The repository is intended for Lua programming-related content and resources.

### Current State

The repository is currently minimal, containing only a `main` file. Previous content (LUA user manual PDF and zip files) has been cleaned up through maintenance PRs.

### Repository Structure

```
lua/
├── .git/           # Git version control
├── main            # Main file (currently contains "git init")
└── CLAUDE.md       # This file - AI assistant guidelines
```

## Development Guidelines

### Branch Naming Convention

- Feature branches created by Claude AI should follow the pattern: `claude/<description>-<session-id>`
- Example: `claude/cleanup-zip-files-01N9Y4Pej3DACqvkEEMzBjsM`

### Git Workflow

1. **Creating branches**: Always branch from the main branch
2. **Commits**: Use clear, descriptive commit messages
3. **Pull Requests**: Create PRs for code review before merging

### File Organization

When adding content to this repository:

- **Lua source files**: Use `.lua` extension, place in root or appropriate subdirectory
- **Documentation**: Use Markdown (`.md`) format
- **Avoid**: Large binary files (PDFs, ZIPs) - these have been cleaned up from the repository

## AI Assistant Instructions

### When Working on This Repository

1. **Always check current state first**: Run `git status` and `git log` to understand the current branch and recent changes
2. **Use the designated feature branch**: Develop on branches prefixed with `claude/`
3. **Keep commits atomic**: One logical change per commit
4. **Document changes**: Update this CLAUDE.md if adding new conventions or significant structure changes

### Code Style for Lua Files

When adding Lua code to this repository, follow these conventions:

```lua
-- Use lowercase with underscores for variable names
local my_variable = "value"

-- Use PascalCase for module names
local MyModule = {}

-- Add comments for complex logic
-- Prefer local variables over globals
```

### Common Tasks

| Task | Command |
|------|---------|
| Check status | `git status` |
| View history | `git log --oneline -10` |
| Create branch | `git checkout -b claude/<name>-<session-id>` |
| Push changes | `git push -u origin <branch-name>` |

## Repository History

- Initial creation with `main` file
- LUA user manual PDF added and later removed (cleanup)
- Zip files added and later removed (cleanup PR #3)
- Repository maintained for Lua-related development

## Contact & Maintenance

- **Owner**: kekhazkft-code
- **Repository**: lua
- **Last Updated**: 2025-11-28
