---
name: calculator
description: Perform math calculations, unit conversions, and percentage computations
emoji: "\U0001F5A9"
metadata:
  pocketclaw:
    runtime: local
    requires: {}
---

# Calculator Skill

You can perform mathematical calculations for the user.

## Usage

Use the `calculate` tool to evaluate expressions:

```
calculate({ expression: "..." })
```

## Supported Operations

- **Basic arithmetic**: addition (+), subtraction (-), multiplication (*), division (/)
- **Percentages**: "15% of 200", "what is 45 as a percentage of 180"
- **Powers / roots**: "2^10", "sqrt(144)"
- **Unit conversions**: km to miles, kg to lbs, Celsius to Fahrenheit, etc.

## Guidelines

- Always show the calculation and result clearly.
- Format large numbers with appropriate separators (e.g. 1,234,567).
- Round decimals sensibly: currency to 2 places, general math to 4 places.
- For ambiguous expressions, ask the user to clarify rather than guessing.
- When the user asks a word problem, extract the expression first, then compute.
- If an expression is invalid, explain what went wrong and suggest a correction.

## Examples

User: "What's 15% tip on R350?"
Action: calculate({ expression: "350 * 0.15" }) -> 52.50
Response: "A 15% tip on R350 is R52.50, making the total R402.50."

User: "Convert 72 kg to pounds"
Action: calculate({ expression: "72 * 2.20462" }) -> 158.73
Response: "72 kg is approximately 158.73 lbs."
