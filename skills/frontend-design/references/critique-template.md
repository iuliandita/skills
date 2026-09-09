# Critique Template: Evidence, Impact, Fix

Review the interface against its brief and the user's task. Report observed problems with
specific locations and remedies. Separate visual observations from behavior verified in a
browser and from assumptions that still need checking.

## 1. Establish the target

Record the page or component, intended audience and task, supplied brand direction, and the
viewports, themes, and states actually inspected. If only a screenshot is available, do not
claim keyboard behavior, contrast measurements, or responsiveness were tested. Missing
evidence is a verification limit, not a defect: do not assign it a severity merely because
the description omitted mobile, focus, or loading behavior.

## 2. Prioritize findings

| Priority | Evidence required |
|---|---|
| P0 | Blocks the core task or creates a severe accessibility failure |
| P1 | Significant observed usability or explicit brief mismatch that should be fixed before release |
| P2 | Localized usability issue or visual inconsistency with a concrete impact |
| P3 | Optional polish with a clear benefit; does not block release |
| info | Working pattern, scope limitation, or personal preference; no fix ticket |

A common style is not evidence of failure. A purple gradient, centered hero, or familiar font
can satisfy the brief. Explain what is unreadable, confusing, inconsistent, or contrary to the
requested identity before assigning priority. Do not infer an accessibility violation from a
preferred design target alone; identify the applicable criterion and its exceptions.

## 3. Write actionable tickets

Keep the main table to 10 findings, ordered by impact. Group repeated instances of the same
cause. Keep info notes outside the ticket table. If more serious findings exist, list them in an appendix with their actual priorities;
the table cap must not hide blockers or relabel them as optional polish.

| ID | Priority | Evidence and location | User impact | Fix and verification |
|---|---|---|---|---|
| 01 | P1 | At the inspected mobile width, the form's save button is clipped outside a non-scrolling panel | Users cannot finish the form | Allow the action row to wrap; recheck the narrow viewport and keyboard reachability |
| 02 | P2 | The settings page uses three labels for the same notification action | Users must infer whether these actions differ | Use one action name and inspect its label, confirmation, and error state |

Use measured values only when measured. Point to the relevant file, selector, or screenshot
region when known. Prefer fixing the demonstrated cause over prescribing an unrelated layout,
font, or color. Preserve the parts that already work.

## 4. Deliver the assessment

- Lead with the interface's main strength or most consequential problem, whichever helps the
  user understand the result; avoid a required praise paragraph
- Optionally open with one or two candid first-impression sentences tied to visible details.
  State a preference as a preference, recommend a specific improvement, and let the evidence
  determine whether it belongs in the findings. Do not add a separate rant section
- Present the prioritized findings and any additional serious findings
- Include optional polish and successful patterns only when they affect the next decision
- State which viewports, themes, states, and interactions were checked and which remain unknown

Use the output contract specified in SKILL.md for a saved critique. Keep the voice direct
without blaming individuals or inflating taste preferences into defects. Critique mode reports proposed fixes;
apply changes only when the user has authorized refinement.
