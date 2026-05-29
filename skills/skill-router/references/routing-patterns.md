# Routing Patterns

## Single Skill

Request: "Review this PR for bugs."
Route: `code-review`
Reason: The user asked for bug-focused review. Do not use `anti-slop` unless the request names
AI-generated code quality.

## Ordered Skills

Request: "Review this decision, then redesign the dashboard."
Route: **jekyll-hyde** -> **frontend-design**
Reason: A process skill (critical review/reframing) must complete before domain work begins.
If no process skill is installed that fits the request, the route is: `No skill -> <domain skill>`.

## Parallel Skills

Request: "Audit this Dockerized API for security and CI issues."
Route: `security-audit`, `ci-cd`, `docker`
Reason: The request spans independent security, pipeline, and container domains.

## Near Miss

Request: "Turn these rough notes into a system prompt."
Route: `prompt-generator`
Near miss: `skill-creator` is only for reusable Agent Skills, not ordinary prompts.
