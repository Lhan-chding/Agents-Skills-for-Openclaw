# Research-First Secure Coding

A reusable Codex skill for research-grounded, security-conscious software work.

This skill is intended for non-trivial coding tasks where implementation should be based on verified evidence such as:
- papers
- official documentation
- high-quality open-source repositories
- technical design discussions
- reproducible engineering references

It instructs Codex to:
- understand and normalize the task before coding
- perform research first when external access is available
- keep an evidence ledger of inspected sources
- synthesize an architecture brief before implementation
- generate modular, maintainable code with tests and run guidance
- apply trust-boundary analysis, prompt-injection defenses, and a lightweight security review

## Repository Contents

- `SKILL.md`: main skill definition
- `agents/openai.yaml`: Codex UI metadata
- `references/`: reusable research and security workflow references
- `templates/`: evidence, architecture, trust-boundary, delivery, and security-review templates
- `evals/`: trigger and adversarial evaluation cases for the skill itself

## Install

Clone this repository into your local Codex skills directory:

```powershell
git clone https://github.com/Lhan-chding/Research-secure-coding-Skills-for-Codex.git "$env:USERPROFILE\.codex\skills\research-first-secure-coding"
```

If the target directory already exists, remove it first or clone elsewhere and copy the folder into:

```text
%USERPROFILE%\.codex\skills\research-first-secure-coding
```

After installation, restart Cursor or the Codex plugin so the new skill is discovered.

## Usage

Invoke the skill explicitly in a Codex conversation:

```text
$research-first-secure-coding First study the relevant papers, official docs, and reference repos, then design and implement a secure modular solution for this task.
```

Typical prompts that should trigger this skill:
- `Help me implement this system based on papers and repos.`
- `First study related methods, then write the code.`
- `Analyze similar projects and adapt the architecture.`
- `Ground the implementation in real references, not guesses.`
- `Reproduce and improve this approach with a clean maintainable codebase.`

This skill is not intended for trivial one-line fixes, tiny syntax questions, or toy examples that do not need research, architecture planning, or security review.

## License

This repository is licensed under Apache License 2.0.

Copyright 2026 lihan.

See [LICENSE](LICENSE) and [NOTICE](NOTICE).
