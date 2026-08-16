# Design system — what exists, and how it is enforced

> Written by measuring the codebase, not by proposing a system for it to grow
> into. Every scale here is made of values the app already ships (CLAUDE.md
> rule 4: this pass changes no visual design). The enforcement, not the
> constants, is the deliverable — a token file nothing checks is documentation
> that rots.

Tokens: [`lib/core/design_tokens.dart`](../../lib/core/design_tokens.dart)
Motion: [`lib/core/motion.dart`](../../lib/core/motion.dart)
Palette: [`lib/core/app_colors.dart`](../../lib/core/app_colors.dart)
Theme: [`lib/core/app_theme.dart`](../../lib/core/app_theme.dart)
Enforcement: [`test/core/design_token_ratchet_test.dart`](../../test/core/design_token_ratchet_test.dart)

## The scales

| Scale | Rungs | Accepted off-scale debt |
|---|---|---|
| Spacing | 4 · 8 · 12 · 16 · 20 · 24 · 32 | 30 |
| Radius | 4 · 8 · 12 · **14** · 16 · 20 · 24 · pill(999) | 28 |
| Elevation | 0 · 4 · 8 | **0 — pinned at zero** |
| Icon size | 14 · 16 · 20 · 24 · 32 · 40 · 48 | 73 |
| Type size | 11 · 12 · 13 · 14 · 16 · 18 · 22 · 26 · 34 | 77 |
| Font weight | w500 · w600 · w700 · w800 · w900 | 0 |
| Raw colour literals outside the palette | — | 30 |
| Motion | 140 / 240 / 360 ms + `Duration.zero` for dispatch | — |

**Radius 14 is measured reality, not a designed rung.** 61 uses, almost all
input fields. Collapsing it into 12 or 16 changes what ships, so it is named
`Radii.input` and documented rather than quietly "fixed".

**Why debt is pinned instead of migrated.** Rewriting ~200 literals across 40
screens would churn hundreds of lines and risk visual regressions on a
safety-critical codebase whose review model depends on small, readable diffs.
The ratchet freezes the drift: new code lands on the scale, and every number
above can only fall. When one falls the test prints the improvement so the
pinned value can be lowered.

## Component conventions

- **Buttons come from the theme.** `ElevatedButtonThemeData`,
  `TextButtonThemeData` and `OutlinedButtonThemeData` in `app_theme.dart` define
  shape, padding and elevation from tokens. Call sites pass content and
  `onPressed`, not geometry. A call site that needs different geometry is a
  signal the theme is wrong, not a licence to inline it.
- **Cards** use `Radii.lg` and `AppColors.cardBg` with a `AppColors.border`
  outline. The readiness card, quick-action cards and timeline rows all follow
  this; deviations are the paywall's highlighted plan card (accent border) and
  the notice cards, which are intentionally distinct.
- **Semantic colour is mandatory for safety states.** `AppColors.emergency`,
  `.success`, `.warning`, `.info`. The ratchet asserts the panic button reaches
  for `emergency` and the readiness card for `success`/`warning`, so a palette
  change cannot leave one surface on the old red.
- **Disabled state** is expressed by `onPressed: null` (theme handles the
  visuals), never by manually dimming a colour.

## Loading, empty and error states

The standard is deliberately narrow — three idioms, no more:

1. **Bounded spinner.** `CircularProgressIndicator` for any wait the app
   initiated and expects to finish. Used everywhere.
2. **Shimmer — splash only.** The splash has nothing to lay a skeleton over, so
   it shimmers its wordmark. The ratchet asserts `splash_screen.dart` is the
   *only* file implementing a shimmer; a second one is drift, not a feature.
3. **Notice card.** A bordered, tinted block with an icon, a bold title and a
   body line — used for offline notices, permission fallbacks and the
   subscription-verification notice. This is the empty/error idiom.

**Loading buttons** show progress in place of their leading icon and set
`onPressed: null` for the duration (see the paywall restore action, covered by
`test/screens/paywall_render_test.dart`).

## Component variations

| Component | Variations | Where |
|---|---|---|
| Action card | free · locked (PRO badge) | home quick actions |
| Panic button | idle (breathing) · armed (pulse) · locked | `panic_button.dart` |
| Status chip | ok (success) · attention (warning) | readiness card |
| Notice card | info · warning · lapsed | readiness card, map, contacts |
| Plan card | standard · highlighted | paywall |
| Countdown | armed · cancelling · failed | `countdown_screen.dart` |

Reduced motion is a cross-cutting variation, not a per-component one:
`ReducedMotionPolicy` parks or suppresses animation and every animated
component asks it.

## Theming

The app ships **one** theme. `main.dart` pins `ThemeMode.dark` and wires both
`theme` and `darkTheme` to `AppTheme.darkTheme`, so there is a single rendered
surface and nothing to keep in sync.

**Decision D-1, taken 2026-08-16: the light theme was deleted.** It had been
maintained but unreachable, and measurement showed why that state rots: it
declared `brightness: Brightness.dark` and differed from `darkTheme` by exactly
one line (`cardColor`). A dark UI is also the safer default for a duress product
used at night — it does not light up a room. Reversible from git if the product
changes its mind; adding a light mode later means a theme switch plus light-surface
palette work and doubled visual QA, which is the cost the decision accepted.
