// ============================================================================
// DESIGN TOKENS — the scales this app already uses, named
// ============================================================================
// This file was written by MEASURING the codebase, not by inventing a system
// and then trying to make the UI match it. CLAUDE.md rule 4 forbids changing
// visual design, so nothing here changes a rendered value: every rung below is
// a value the app already ships, and the rungs were chosen because they are
// the ones that actually dominate.
//
// Measured over lib/ before this file existed:
//
//   BorderRadius.circular : 13 distinct values; 12/14/16/20 accounted for 209
//                           of ~254 uses, plus 999 for pills
//   EdgeInsets.all        : 12 distinct values; 12/14/16/18/20/24 dominant
//   elevation             : already a clean 3-rung scale (0 / 4 / 8)
//   icon size             : 20 distinct values -- the genuinely scattered one
//   durations/curves      : already tokenised in `Motion`
//
// So this is not a greenfield token system. Two of the six scales were already
// real, one (motion) has its own documented file, and the honest gap was that
// the rest had no name and no way to stop drifting.
//
// HOW THIS IS ENFORCED, and why that matters more than the constants:
// `test/core/design_token_ratchet_test.dart` counts values that fall OFF these
// scales and pins the current count. It does not demand a big-bang migration —
// that would churn hundreds of lines and risk exactly the visual regressions
// rule 4 exists to prevent. It stops the drift from growing, the same way
// `source_file_size_ratchet_test.dart` handles oversized files. Accepted debt
// is recorded there, in numbers, rather than hidden here.
//
// Motion deliberately lives in `motion.dart` and is NOT duplicated here.
// ============================================================================

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Spacing scale. A 4px base grid; the rungs are the multiples actually used.
abstract final class Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Every rung, for the ratchet and for exhaustive tests.
  static const List<double> scale = <double>[xxs, xs, sm, md, lg, xl, xxl];
}

/// Corner radius scale. `pill` is the fully-rounded case (chips, the SOS ring).
abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// 14 is not a designed rung, it is measured reality: 61 uses, almost all of
  /// them input fields and the cards that sit next to them. Changing it to 12
  /// or 16 is a VISUAL change, which this pass is not allowed to make
  /// (CLAUDE.md rule 4). It is on the scale so the ratchet does not report 61
  /// false violations, and it is named honestly so a future design pass can
  /// decide to collapse it deliberately rather than discover it by accident.
  static const double input = 14;

  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;

  static const List<double> scale = <double>[
    xs,
    sm,
    md,
    input,
    lg,
    xl,
    xxl,
    pill,
  ];
}

/// Elevation scale. Already a three-rung system before this file: flat
/// surfaces, floating actions, dialogs. Shadows come from `AppColors.shadow`.
abstract final class Elevation {
  static const double flat = 0;
  static const double raised = 4;
  static const double overlay = 8;

  static const List<double> scale = <double>[flat, raised, overlay];
}

/// Shadow scale — the SEPARATE half of MP-03-009.
///
/// [Elevation] above covers Material's `elevation:` property, which this app
/// barely uses (26 of 29 sites are 0). Depth is actually drawn with hand-rolled
/// `BoxShadow`, and THAT was the convention-not-a-token half of the finding.
///
/// MEASURED before this scale existed: 27 `BoxShadow(` sites in lib/, with 14
/// distinct blur radii (20 x6, 8 x4, 6 x4, 24 x2, 12 x2, then 60/40/30/28/18/
/// 15/14/10 once each) and five distinct offsets. Grouping them by what they
/// are FOR, rather than by number, collapses cleanly into four rungs plus two
/// tinted variants:
///
///   resting   neutral, blur 6,  (0,2)  -- list rows and cards at rest
///   raised    neutral, blur 8,  (0,2)  -- the same surfaces lifted
///   overlay   black,   blur 24, (0,12) -- sheets floating over the map
///   brandGlow tinted,  blur 20, (0,8)  -- the primary CTA's coloured glow
///   tintedCard tinted, blur 14, (0,8)  -- soft category tint on a card
///
/// DELIBERATELY NOT TOKENISED: the seven ANIMATED glows (splash logo, onboarding
/// icon pulse, emergency-call header, map marker) compute `blurRadius` and
/// `spreadRadius` from an animation value every frame -- `blurRadius: 30 +
/// (glowValue * 30)`. A static rung cannot express an interpolation, and
/// flattening them into one would delete motion the app deliberately has. The
/// point of this scale is consistency, not a lower token count; see the note in
/// MP-03-009.
abstract final class Shadows {
  /// Cards and list rows at rest. The most common neutral shadow in the app.
  static const List<BoxShadow> resting = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// The same neutral surface, lifted one rung.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Sheets and panels floating over map tiles, where the background is
  /// photographic and a neutral-alpha shadow reads better than the token grey.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadowOverlay,
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// The coloured glow under a primary call to action.
  static List<BoxShadow> brandGlow(Color color) => <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// A card tinted by its own category colour, far softer than [brandGlow].
  static List<BoxShadow> tintedCard(Color color) => <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ];

  /// Every static rung, for the ratchet test.
  static const List<List<BoxShadow>> staticScale = <List<BoxShadow>>[
    resting,
    raised,
    overlay,
  ];
}

/// Icon sizes, named by the ROLE each one plays and sized by what the app
/// already renders.
///
/// ## Why the names changed
///
/// The first version of this scale was `xs/sm/md/lg/xl/xxl/hero` at
/// 14/16/20/24/32/40/48, and it had **zero consumers** — which is how
/// `MP-04-012` came to be an open row rather than a closed one. Measuring the
/// tree explained why nobody adopted it: the two most common icon sizes in the
/// app after 20 are **18 (24 sites)** and **22 (19 sites)**, and neither was on
/// the scale. A migration onto it would have moved 43 rendered icons, which is
/// a visual change CLAUDE.md rule 4 reserves to the owner. So the scale was
/// derived from usage instead of the other way round, and every rung below is a
/// value the app was already drawing — the migration changes **no pixels**,
/// exactly like the ZLayer / Breakpoints / DensityTokens migrations before it.
///
/// ## Visual size is NOT hit target
///
/// Every value here is the size of the GLYPH. None of them is a touch target: a
/// 20 dp icon lives inside a >= 48 dp interactive box, which is asserted
/// separately by `touch_target_geometry_test.dart`. Growing a role to reach
/// 48 dp would be fixing the wrong thing.
abstract final class IconSizes {
  /// Inline with body text: chevrons, tiny meta marks. (14 dp, 10 sites)
  static const double inline = 14;

  /// Dense list metadata. (16 dp, 13 sites)
  static const double dense = 16;

  /// Leading glyph of an inline notice or compact row. (18 dp, 24 sites)
  static const double listItem = 18;

  /// The standard action glyph — the app's most common icon size.
  /// (20 dp, 36 sites)
  static const double action = 20;

  /// A prominent row or section-header glyph. (22 dp, 19 sites)
  static const double emphasis = 22;

  /// Dialog and settings-tile glyphs. (24 dp, 12 sites)
  static const double dialog = 24;

  /// A feature mark inside a circular badge. (36 dp, 9 sites)
  static const double feature = 36;

  /// A screen-level illustrative mark. (40 dp, 7 sites)
  static const double illustration = 40;

  /// Empty-state and hero artwork. (48 dp, 3 sites)
  static const double hero = 48;

  static const List<double> scale = <double>[
    inline, dense, listItem, action, emphasis, dialog, feature, illustration,
    hero,
  ];

  /// Sizes the app renders that are deliberately NOT roles.
  ///
  /// Each is a one-off piece of artwork or a single decorative glyph; promoting
  /// any of them would be inventing a role from one site. Listed rather than
  /// pattern-matched, so a NEW off-scale size is still visible as drift.
  static const Map<String, String> documentedExceptions = <String, String>{
    '12': 'the lock glyph inside the panic button label (panic_button.dart)',
    '26': 'PIN keypad backspace and three nav/list glyphs',
    '28': 'the locked-Pro row mark (subscription_management_screen.dart)',
    '32': 'two permission-dialog marks (permission_helper.dart)',
    '34': 'three round-button glyphs sized to their button',
    '42': 'two full-screen failure marks (emergency + countdown)',
    '52': 'onboarding and legal-disclaimer artwork',
    '56': 'check-in and profile avatars',
    '60': 'the siren dialog mark',
    '68': 'the splash shield',
    '70': 'the caller avatar on the fake-call and emergency screens',
  };
}

/// Type scale, measured the same way as the rest.
///
/// 21 distinct font sizes were in use, clustered hard on 12-16 (184 of 335
/// uses). The rungs below are those clusters plus the display sizes the
/// onboarding and countdown screens genuinely need.
///
/// A note on why this is a SCALE and not a `TextTheme`: the app currently sets
/// `fontSize` inline at 335 sites and reads `Theme.of(context).textTheme`
/// nowhere. Routing all of it through the theme is a real refactor with real
/// visual risk, so this pass names the scale and ratchets it; the migration is
/// tracked as debt rather than pretended away.
abstract final class TypeScale {
  /// Fine print: legal footnotes, chip captions.
  static const double caption = 11;

  /// Secondary body: helper lines, card subtitles.
  static const double bodySmall = 12;

  /// The workhorse. Card body, list rows.
  static const double body = 13;

  /// Emphasised body, button labels.
  static const double bodyLarge = 14;

  /// Section intros and dialog body.
  static const double subtitle = 16;

  /// Section headings.
  static const double title = 18;

  /// Screen headings.
  static const double headline = 22;

  /// Onboarding and consent screen titles.
  static const double display = 26;

  /// The countdown number and the fake-call caller name.
  static const double hero = 34;

  static const List<double> scale = <double>[
    caption,
    bodySmall,
    body,
    bodyLarge,
    subtitle,
    title,
    headline,
    display,
    hero,
  ];

  /// The four weights actually in use. w500 appears 14 times and is folded into
  /// [medium]; w900 (11 uses) is reserved for the emergency surfaces.
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
  static const FontWeight emergency = FontWeight.w900;

  static const List<FontWeight> weights = <FontWeight>[
    medium,
    semiBold,
    bold,
    heavy,
    emergency,
  ];
}

/// Stacking order. Flutter has no z-index, so ordering is expressed by widget
/// order inside a Stack and by route layering. These names exist so a new
/// overlay has an intended place rather than "wherever it was appended".
abstract final class ZLayer {
  /// Page content.
  static const int content = 0;

  /// Decorative glow/pulse rings behind an interactive control.
  static const int ambient = 10;

  /// Sticky headers, bottom bars.
  static const int chrome = 20;

  /// SnackBars and inline banners.
  static const int notice = 30;

  /// The privacy shield that covers the app in the recents switcher, and the
  /// PIN gate. Nothing may render above these.
  static const int shield = 40;
}

/// Breakpoints, taken from the checks the screens already make. This app is
/// portrait-phone-only by an explicit product decision, so these are phone
/// size classes rather than tablet/desktop breakpoints.
abstract final class Breakpoints {
  /// Below this the layout drops to its tightest horizontal padding.
  static const double narrowWidth = 340;

  /// Above this the layout uses its most generous horizontal padding.
  static const double wideWidth = 400;

  /// Below this, vertical rhythm compresses (the `shortScreen` path).
  static const double shortHeight = 700;

  static bool isNarrow(Size size) => size.width <= narrowWidth;
  static bool isWide(Size size) => size.width > wideWidth;
  static bool isShort(Size size) => size.height < shortHeight;
}

/// Component density. One switch, driven by [Breakpoints.shortHeight], which is
/// what the screens already do ad hoc under the name `shortScreen`.
enum Density { comfortable, compact }

abstract final class DensityTokens {
  static Density of(Size size) =>
      Breakpoints.isShort(size) ? Density.compact : Density.comfortable;

  /// Gap between sibling cards.
  static double gap(Density d) =>
      d == Density.compact ? Spacing.xs : Spacing.sm + 2;

  /// Gap between major sections.
  static double sectionGap(Density d) =>
      d == Density.compact ? Spacing.sm : Spacing.lg;

  /// Horizontal page padding for a given width.
  static double horizontalPadding(Size size) {
    if (Breakpoints.isWide(size)) return Spacing.xl;
    return Breakpoints.isNarrow(size) ? Spacing.md : Spacing.lg;
  }
}


/// Odak göstergesi geometrisi — WCAG 1.4.11 (Non-text Contrast, AA) ve
/// WCAG 2.2 SC 2.4.13 (Focus Appearance).
///
/// Bu runglar ÖLÇÜMDEN geldi, tasarımdan değil: API 36 emülatöründe render
/// edilmiş pikseller okundu. Material'in varsayılan odak kaplaması ayar
/// satırlarında rgb(47,69,89) veriyordu; komşu renklere karşı 1.46-1.76:1,
/// yani 3:1 barının altında. Profil kartı ve Pro satırında ise kaplama
/// çocuğun opak arka planının ALTINDA kaldığı için hiç görünmüyordu (1.00:1).
abstract final class FocusIndicator {
  /// Yüksek kontrastlı iç halka kalınlığı.
  static const double ringWidth = 2;

  /// Dış kontur — iç halkanın görünmediği parlak yüzeyler için.
  static const double outlineWidth = 2;

  /// SC 2.4.13 alan hesabı için toplam kalınlık.
  static const double totalWidth = ringWidth + outlineWidth;

  /// WCAG 1.4.11'in gerektirdiği asgari kontrast oranı.
  static const double minContrast = 3.0;
}
