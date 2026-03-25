# Anti-Slop Research Sources

Read this file for deeper context on specific findings or when the user wants citations. Covers all supported languages (TS/JS, Python, Bash/Shell, Terraform, Ansible, Helm, Kubernetes).

## Key Statistics

- AI-generated PRs average 10.83 issues vs 6.45 for human PRs (1.7x more) -- CodeRabbit 2025
- AI coding assistants produce output 2x as verbose as Stack Overflow answers -- LeadDev
- AI models are 9x more prone to use `any` than human developers -- arxiv.org/html/2602.17955
- 82% of AI-generated catch blocks fail to distinguish error types -- AlterSquare
- 76% of AI-generated code omits critical network timeouts -- AlterSquare
- 25-38% of AI-generated code relies on deprecated APIs -- multiple sources
- ~20% of AI-suggested package dependencies point to non-existent libraries -- multiple sources
- 45% of AI-generated code contains security flaws -- Veracode 2025

## Source List

- KarpeSlop linter (3-axis slop model): github.com/CodeDeficient/KarpeSlop
- AlterSquare codebase rescue reports: altersquare.io/rescued-15-plus-codebases-ai-tools-pattern/
- AlterSquare "clean code" critique: altersquare.io/ai-generated-code-next-refactor-will-prove-its-not-clean/
- CodeRabbit AI vs Human report: coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report
- LeadDev verbosity study: leaddev.com/ai/ai-coding-assistants-are-twice-as-verbose-as-stack-overflow
- Mining Type Constructs in AI Code: arxiv.org/html/2602.17955
- Aviator slop avoidance guide: aviator.co/blog/how-to-avoid-ai-code-slop/
- Continue.dev slop article: blog.continue.dev/fight-code-slop-with-continuous-ai
- Addy Osmani on React AI code: addyo.substack.com/p/how-good-is-ai-at-coding-react-really
- Simon Willison agentic anti-patterns: simonwillison.net/guides/agentic-engineering-patterns/anti-patterns/
- InfoQ on AI "convenience loops": infoq.com/news/2026/03/ai-reshapes-language-choice/
- Sloplint: github.com/dannote/sloplint
- Anti-slop (peakoss): github.com/peakoss/anti-slop

## The "No Soul" Problem

The hardest slop to detect programmatically. Code that compiles, passes tests, and follows conventions -- but feels generic. Signs:

- Every module follows the exact same structure regardless of its role
- Naming is correct but bland (follows conventions without adding domain clarity)
- Error messages are grammatically perfect but uninformative ("An error occurred while processing your request")
- Code reads like documentation of itself rather than a solution to a problem

This requires human judgment. The skill flags patterns, but the user decides what has soul and what doesn't.
