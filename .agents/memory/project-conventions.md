---
type: project
created: 2026-05-25
updated: 2026-07-12
---

# Project Conventions

## Git Workflow
- Always create a new dedicated branch for major code changes.
- Branch name format should follow: `feature/[task-slug]` or `fix/[bug-slug]`.

## Supported AI platforms (AG Kit)
- AG Kit **only supports Gemini CLI and Google Antigravity**.
- Do not claim compatibility with Claude Code, Cursor, Copilot, Windsurf, or other assistants unless the user explicitly expands scope.
- Copy on the website, docs, FAQ, README, and marketing should describe AG Kit as a toolkit for Gemini CLI / Antigravity-style agent setups.

## Viewport Directive Scope Rules (MANDATORY)
- **`MOBILE VIEW`**: Strictly modify ONLY mobile view code (Tailwind base classes without breakpoint prefixes, e.g. `py-5`, `text-xs`). NEVER alter desktop classes (`sm:`, `md:`, `lg:`, `xl:`).
- **`DESKTOP VIEW`**: Strictly modify ONLY desktop view code (Tailwind responsive breakpoint prefixes, e.g. `sm:`, `md:`, `lg:`, `xl:`, `2xl:`). NEVER alter base mobile classes.
- **`UNIVERSAL VIEW`**: Modify both mobile and desktop responsive styles simultaneously.
