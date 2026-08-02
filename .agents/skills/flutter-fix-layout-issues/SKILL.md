---
name: flutter-fix-layout-issues
description: Fixes Flutter layout errors (overflows, unbounded constraints) using Dart and Flutter MCP tools. Use when addressing "RenderFlex overflowed", "Vertical viewport was given unbounded height", or similar layout issues.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 19:45:59 GMT
---

# Resolving Flutter Layout Errors

## Contents
- [Constraint Violation Diagnostics](#constraint-violation-diagnostics)
- [Layout Error Resolution Workflow](#layout-error-resolution-workflow)
- [Examples](references/examples.md)

## Constraint Violation Diagnostics

Flutter layout operates on a strict rule: **Constraints go down. Sizes go up. Parent sets position.** Layout errors occur when this negotiation fails, typically due to unbounded constraints or unconstrained children.

Diagnose layout failures using the following error signatures:

* **"Vertical viewport was given unbounded height"**: Triggered when a scrollable widget (`ListView`, `GridView`) is placed inside an unconstrained vertical parent (`Column`). The parent provides infinite height, and the child attempts to expand infinitely.
* **"An InputDecorator...cannot have an unbounded width"**: Triggered when a `TextField` or `TextFormField` is placed inside an unconstrained horizontal parent (`Row`). The text field attempts to determine its width based on infinite available space.
* **"RenderFlex overflowed"**: Triggered when a child of a `Row` or `Column` requests a size larger than the parent's allocated constraints. Visually indicated by yellow and black warning stripes.
* **"Incorrect use of ParentData widget"**: Triggered when a `ParentDataWidget` is not a direct descendant of its required ancestor. (e.g., `Expanded` outside a `Flex`, `Positioned` outside a `Stack`).
* **"RenderBox was not laid out"**: A cascading side-effect error. Ignore this and look further up the stack trace for the primary constraint violation (usually an unbounded height/width error).

## Layout Error Resolution Workflow

Copy and use this checklist to systematically resolve layout constraint violations.

### Task Progress
- [ ] Run the application in debug mode to capture the exact layout exception in the console.
- [ ] Identify the primary error message (ignore cascading "RenderBox was not laid out" errors).
- [ ] Apply the conditional fix based on the specific error type:
  - **If "Vertical viewport was given unbounded height"**: Wrap the scrollable child (`ListView`, `GridView`) in an `Expanded` widget to consume remaining space, or wrap it in a `SizedBox` to provide an absolute height constraint.
  - **If "An InputDecorator...cannot have an unbounded width"**: Wrap the `TextField` or `TextFormField` in an `Expanded` or `Flexible` widget.
  - **If "RenderFlex overflowed"**: Constrain the overflowing child by wrapping it in an `Expanded` widget (to force it to fit) or a `Flexible` widget (to allow it to be smaller than the allocated space).
  - **If "Incorrect use of ParentData widget"**: Move the `ParentDataWidget` to be a direct child of its required parent. Ensure `Expanded`/`Flexible` are direct children of `Row`/`Column`/`Flex`. Ensure `Positioned` is a direct child of `Stack`.
- [ ] Execute Flutter hot reload.
- [ ] Run validator -> review errors -> fix: Inspect the UI to verify the red/grey error screen or yellow/black overflow stripes are resolved. If new layout errors appear, repeat the workflow.

## Examples

For complete input/output Dart examples covering unbounded height (`ListView` in `Column`), unbounded width (`TextField` in `Row`), and `RenderFlex` overflow, see [examples.md](references/examples.md).
