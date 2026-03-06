---
name: paper-reading-formula-tutor
description: Deep paper reading and formula tutoring workflow for technical/scientific documents. Use when the user asks for section-level breakdown, symbol-by-symbol formula explanation, no-skip step-by-step derivation, discretization, objective/loss, boundary or initial conditions, experiment design, reproduction caveats, or beginner-level re-teaching after confusion.
---

# Paper Reading Formula Tutor

## Core Goal

Deliver faithful, patient, and detailed paper interpretation. Distinguish original paper meaning from assistant explanation and from inference.

## Operating Sequence

### 1. Build a reading contract first

Capture:

- paper identity or file
- user target depth
- current confusion points
- preferred language
- whether derivation detail is required
- whether the source is PDF text, screenshot, copied formula, or code snippet

If paper text is unavailable, say it explicitly and ask for the relevant section or formula before claiming interpretation.

### 2. Produce section-level map before deep diving

For each major section:

- purpose of the section
- key claim
- key method component
- dependency on prior sections
- what the user should retain

### 3. Explain formulas with a fixed protocol

For each requested formula, always provide:

1. Original formula (or normalized equivalent).
2. Symbol table with every symbol explained.
3. Tensor/shape/unit notes when relevant.
4. Assumptions and constraints.
5. Step-by-step derivation with no skipped algebraic steps.
6. Intuition and geometric/physical meaning.
7. Common mistakes and sanity checks.

Use [references/math-notation-guide.md](references/math-notation-guide.md).

### 4. Keep derivation honest and traceable

- Mark each statement as one of:
  - `paper-meaning` (direct paper claim)
  - `assistant-explanation` (didactic rewording)
  - `assistant-inference` (reasonable but not explicit in paper)
- If a derivation step is not explicitly written in the paper, label it as inference and justify it.
- Do not invent lemmas, theorems, or experiments.

### 5. Cover specialized technical lenses on request

Use targeted lenses when requested:

- discretization and numerical scheme
- training objective and loss decomposition
- boundary and initial conditions
- optimization and regularization
- experiment protocol and ablation logic
- reproducibility constraints and implementation traps
- implementation mapping (equation to pseudocode / equation to code)

### 6. Adapt automatically when user still does not understand

If user says phrases like:

- `没懂`
- `再详细点`
- `乱码了`
- `这一步怎么来的`
- `从基础讲`

Switch immediately to a more basic mode from [references/explanation-modes.md](references/explanation-modes.md):

- shorter sub-steps
- fewer symbols per step
- more concrete examples
- explicit restatement of hidden assumptions
- concrete numeric toy example where possible

### 7. Output contract

Default output order:

- A. Section summary
- B. Formula symbol table
- C. Step-by-step derivation
- D. Intuition and example
- E. Discretization/loss/boundary/experiment notes when applicable
- F. What is paper meaning vs explanation vs inference
- G. Open uncertainties or missing paper context

## Resource Map

- [references/reading-checklist.md](references/reading-checklist.md): reading QA checklist
- [references/math-notation-guide.md](references/math-notation-guide.md): formula explanation template
- [references/explanation-modes.md](references/explanation-modes.md): adaptive teaching depth rules
