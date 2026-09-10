# Anti-Slop Research Sources

Read this file for deeper context on specific findings or when the user wants citations. Covers all supported languages (TS/JS, Python, Bash/Shell, Terraform, Ansible, Helm, Kubernetes).

## How to use this research

Reports and experiments describe particular samples, tools, and settings. They do not establish
an error rate for the code under review or prove who wrote it. Verify the original methodology
before quoting a statistic; base each finding on the current repository's behavior and contracts.

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

## Community / Recent Signals

- Medium: "The Illusion of Fluency and the Risk of Overtrust in AI-Assisted Coding" - medium.com/@rafaelperin/the-illusion-of-fluency-and-the-risk-of-overtrust-in-ai-assisted-coding-5ca8fca84907
- Medium: "I Let AI Write Tests for 2 Months. 100% Coverage. 0% Useful." - medium.com/lets-code-future/i-let-ai-write-tests-for-2-months-100-coverage-0-useful-heres-what-broke-in-production-c088a5ecd030
- DEV: "AI Writes Your Tests. Here's What It Systematically Misses." - dev.to/anhnguyensynctree/ai-writes-your-tests-heres-what-it-systematically-misses-3a38
- Hacker News discussion: "Toward automated verification of unreviewed AI-generated code" - news.ycombinator.com/item?id=47397367
- Lemmy discussion amplifying AI-vs-human code quality concerns - lemmy.world/post/40761686

## Repeated Failure Themes

- Fluent output gets over-trusted because it looks intentional even when it is not grounded.
- Generated tests often mirror the implementation and validate the same wrong assumption.
- Models use fallback defaults, broad catches, and extra wrappers to hide uncertainty.
- Hallucinated APIs, flags, resource fields, and version mismatches are common in IaC and shell-heavy repos because the syntax is plausible enough to survive casual review.

## The "No Soul" Problem

The hardest slop to detect programmatically. Use concrete maintenance and usability costs rather than a generic feeling. Examples to inspect:

- Every module follows the exact same structure regardless of its role
- Naming makes distinct domain concepts difficult to tell apart
- Error messages are grammatically perfect but uninformative ("An error occurred while processing your request")
- Code reads like documentation of itself rather than a solution to a problem

Shared structure and conventional names are often useful. Report a finding only when the example causes a concrete problem for readers, users, or maintainers.
