# Trigger Evaluation Cases

Use these cases to check whether the skill activates only when it should and whether the required workflow stages occur in order.

## Should Trigger

1. Prompt: `Help me implement this system based on three papers and two reference repos. First study related methods, then design a clean Python package with tests.`
   Expected: Activate the skill, normalize the task, plan research, inspect relevant sources, produce an evidence ledger, synthesize an architecture, define a file tree, then implement and self-review.

2. Prompt: `Reproduce this approach from the official repo, compare it with newer variants, and extend it for our dataset.`
   Expected: Activate the skill, gather reproducibility constraints, inspect papers and repositories, compare approaches, and produce a secure modular extension plan.

3. Prompt: `Analyze the architecture of similar open-source projects and adapt the best ideas into a maintainable service with auth and database access.`
   Expected: Activate the skill, include trust-boundary analysis, dependency scrutiny, and a security review before delivery.

4. Prompt: `Ground the implementation in real references, not guesses. Research first, then build a secure and maintainable implementation.`
   Expected: Activate the skill and enforce the research-first workflow explicitly.

5. Prompt: `Review this non-trivial service design and point out correctness, dependency, and security risks before we start coding.`
   Expected: Activate the skill, research relevant references if access exists, and present findings with security focus.

## Should Not Trigger

1. Prompt: `What does list.append do in Python?`
   Expected: Do not activate. Answer directly.

2. Prompt: `Fix this missing comma in my JSON file.`
   Expected: Do not activate. Apply the tiny fix directly.

3. Prompt: `Write a toy hello world script in Bash.`
   Expected: Do not activate unless the user explicitly asks for research or security architecture.

4. Prompt: `Explain what a REST API is in one paragraph.`
   Expected: Do not activate. Provide the explanation directly.

5. Prompt: `Rename this variable to something clearer.`
   Expected: Do not activate. Make the small edit directly.

## Workflow Integrity Checks

Mark the run as failed if any of these happen:
- coding starts before the task is normalized
- sources are cited without being opened
- fewer than 10 relevant external sources are inspected when access is available and more are credibly available
- filler sources are added just to hit the count
- the architecture brief is skipped before implementation
- the file tree is omitted before code
- security-sensitive surfaces are not identified
- the final answer hides uncertainty or mixes assumptions with verified findings
