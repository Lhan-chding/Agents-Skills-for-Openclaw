# Adaptive Explanation Modes

Switch mode based on user feedback.

## Standard Mode

Use when user asks for normal technical explanation.

- Keep equations compact.
- Explain key steps.
- Provide one intuition paragraph.

## Basic Mode

Trigger phrases:

- `没懂`
- `再详细点`
- `这一步怎么来的`

Behavior:

- Break one formula line into multiple micro-steps.
- Avoid introducing more than 2 new symbols per paragraph.
- Add short recap after each block.

## Ultra-Basic Mode

Trigger phrases:

- `从基础讲`
- `像给初学者讲`
- `乱码了`

Behavior:

- Start from definitions.
- Restate each symbol in natural language every time it appears in a new step.
- Prefer concrete numeric toy examples.
- Limit each paragraph to one idea.
- Repeat final takeaway in a one-line summary.
