# Design Defaults Worth Questioning

Use this catalogue to question unexamined choices. A familiar pattern is a problem when it
obscures the task, conflicts with the brief, or fills space without useful content. Explicit
user direction and established brand conventions take precedence. The alternatives below
are possibilities to test, not a replacement house style.

Be specific and slightly opinionated: "Every panel has equal weight; the urgent queue needs
to stand out" is useful. Calling a font lazy or a palette tasteless is not a diagnosis.

## Composition

| Pattern to inspect | What would make it a problem? | Possible improvement |
|---|---|---|
| Identical feature cards | Different priorities appear equal, or vague claims hide the actual product | Show a concrete workflow; group comparable items and emphasize the primary task |
| Centered hero with two buttons | Long prose becomes hard to scan or competing actions confuse the next step | Shorten the copy, clarify action priority, or change alignment to fit the content |
| Dashboard by reflex | Metrics and charts appear without a monitoring or decision-making task | Show the editor, queue, catalog, or other interface the user actually needs |
| Centered body text | Readers lose the start of each line across long paragraphs | Use reading-direction alignment and a comfortable line length |
| Numbered decorative sections | Numbers imply a sequence that does not exist | Keep numbering for steps or reference; otherwise let headings and spacing organize content |
| Identical spacing everywhere | Group boundaries and priority are difficult to perceive | Use tighter spacing within a group and more space between unrelated groups |

Cards can group content without being clickable. Centered composition can suit a concise
message. A dashboard can need several equal metrics. Keep these choices when the information
and task justify them; do not replace every grid with asymmetric editorial columns.

## Color, typography, and surfaces

| Pattern to inspect | What would make it a problem? | Possible improvement |
|---|---|---|
| Reused category palette | Unrelated products get the same identity regardless of the brief | Derive semantic color roles from supplied brand, imagery, and context |
| Purple or pastel gradients | Text loses contrast across the gradient or the treatment contradicts the brand | Adjust the gradient or foreground, or use a solid treatment where it improves legibility |
| Accent on one headline word | Emphasis implies a distinction the sentence does not mean | Let the whole headline carry the message, or emphasize a meaningful phrase |
| Familiar sans-serif everywhere | Roles lack differentiation or glyph coverage fails the audience | Tune scale, weight, spacing, and line length before adding a typeface |
| Display font added by reflex | A second family introduces noise or slows loading without a distinct role | Use one family with clear roles, or retain the pair when it serves the identity |
| Frosted panels | Blur obscures content or adds rendering cost without a meaningful layer | Use a solid surface or reserve translucency for useful depth |
| Same radius and shadow on everything | Surface hierarchy is unclear | Define a small token system tied to component roles |
| Unmodified component kit | Default hierarchy and density work poorly for the domain | Keep accessible primitives while adapting layout, state treatment, and content |

Cream-and-serif editorial pages, neon-on-black tools, and border-heavy minimalism can become
reflexes too. No palette, font, or corner radius is inherently evidence of generated design.
Measure actual contrast and inspect the composition before prescribing a replacement.

## Imagery and trust

- **Icons on every label:** remove icons that add no meaning; keep familiar ones that improve
  recognition. Preserve consistent stroke, size, and alignment within the chosen family.
- **Emoji or stock illustration:** assess audience fit and information value. A deliberate
  illustration can support a brand; unrelated decoration cannot explain the product.
- **Product screenshot:** show the relevant task or state with representative content, a useful
  crop, and readable detail. A tilted browser frame is optional, not proof of quality or failure.
- **Partner logos and testimonials:** substantiate relationships and quotes. Remove fabricated
  endorsements; do not invent real-looking people, metrics, or partnerships to fill space.
- **Repeated testimonial cards:** choose structure around the amount and credibility of actual
  evidence. One strong sourced quote may communicate more than several generic claims.

## Behavior

- **Loading effects:** match the indicator to the wait and keep claims accurate. A progress bar
  needs measurable progress; a skeleton needs a known content shape. Sparkles alone do not
  establish whether a feature uses AI.
- **Modal on arrival:** check whether the interruption is required for the task. Prefer inline
  notices for optional promotion; preserve necessary consent, access, or safety decisions.
- **Toasts for form feedback:** put feedback near the affected control when it needs attention
  there. Use a toast when the event is independent of the current view.
- **Celebration on routine actions:** use ordinary confirmation for routine work unless a playful
  response is part of the brief. Reserve stronger celebration for a meaningful milestone.
- **Autoplay media:** assess bandwidth, distraction, and text readability. Provide pause controls
  and respect reduced motion; a still image may carry the same information more effectively.
- **Decorative motion:** make feedback explain a change. Remove recurring movement that competes
  with reading or hides state; keep intentional motion when the brief and user needs support it.

## Critique and refinement

Describe the visible detail, its location, and its effect on the task or brief. A pattern name
helps explain a finding but is not evidence by itself. Keep preferences and unknown behavior
out of severity-ranked fix tickets. When refining, solve demonstrated problems while preserving
legitimate user direction. Offer a stronger choice with a reason, then respect the decision.
