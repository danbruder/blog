# Ink & Lime — a portable design system

Extracted from this blog (danbruder/blog), internally called "system v2."
This document is written so an agent can read it once and apply the same
visual language to a *different* codebase — a Next.js app, a static site, a
Rails view, whatever. It describes principles, not just values, because the
principles are what let you improvise a component the source site doesn't
have (e.g. a pricing table) without breaking the system.

Companion files in this directory:
- `tokens.css` — drop-in CSS custom properties + base element styles.
  Framework-agnostic; works with plain HTML, Tailwind, or anything else.
- `tailwind.config.snippet.js` — how to wire `tokens.css` into a Tailwind
  config, if the target project uses Tailwind.

## Philosophy (read this before copying any value)

Five rules generate almost every visual decision in this system. When you
need to design something new, derive it from these rather than inventing a
new pattern:

1. **Paper, not chrome.** The page is a printed sheet, not a piece of glass
   or plastic. No border-radius, anywhere. No box-shadow used for elevation.
   No gradients on surfaces. Depth comes from a 1px rule, never a blur.
2. **One accent, spent on purpose.** The palette is neutral (paper/ink
   grays) plus exactly one loud color (lime). Lime is not decoration — it
   marks the one thing that matters on a screen: link hover, the active nav
   item's dot, a button's hover state, `::selection`. If everything is
   accented, nothing is. A secondary "signal" color (cobalt/blue) exists
   only for code syntax highlighting — it never appears in UI chrome.
3. **The highlighter, not the shadow.** Hover states don't lift, scale, or
   glow. They get struck through with a solid lime block, ink-on-lime text.
   Think highlighter pen over a printed page, not a raised button. This is
   the system's single most identifying interaction, and it's what most
   distinguishes it from generic "flat design."
4. **Type does the decorating.** There is no illustration system, no icon
   set, no imagery language beyond the occasional bordered photo. Visual
   interest comes from a tight display face contrasted against a humanist
   body face, oversized headlines, and uppercase tracked-out labels doing
   the job icons usually do.
5. **Structure is drawn with hairlines.** Tables, card grids, and page
   sections are bounded by 1px borders that share edges (no double
   borders — see the `.cells` pattern) rather than by padding + shadow +
   radius. The grid is visible, not implied.

If a request doesn't fit these rules — e.g. "add a drop shadow" or "round
the corners" — that's a signal the request is asking you to leave the
system, not a gap in it. Flag it rather than silently softening the system.

## Design tokens

All color resolves through CSS custom properties on `:root`, re-pointed by
`[data-theme="dark"]`. Never hardcode a hex/oklch color in a component;
reference the token. Values are OKLCH (perceptually uniform lightness, so
light/dark pairs stay visually balanced) — sRGB hex equivalents are given
for tools that don't support `oklch()`.

| Token | Light | Dark | Purpose |
|---|---|---|---|
| `--color-paper` | `oklch(0.978 0.003 250)` ≈ `#F7F8F8` | `oklch(0.175 0.012 255)` ≈ `#20242A` | Page background |
| `--color-paper-2` | `oklch(0.956 0.004 250)` ≈ `#EEF0F0` | `oklch(0.215 0.013 255)` ≈ `#282D34` | Recessed wells (code blocks, active nav row) |
| `--color-paper-3` | `oklch(0.925 0.005 250)` ≈ `#E3E5E6` | `oklch(0.262 0.014 255)` ≈ `#323841` | Stronger recess / active nav background |
| `--color-ink` | `oklch(0.185 0.015 255)` ≈ `#1B1F26` | `oklch(0.955 0.005 250)` ≈ `#F2F3F4` | Primary text, primary borders, headings |
| `--color-ink-2` | `oklch(0.415 0.013 255)` ≈ `#4E535C` | `oklch(0.775 0.008 250)` ≈ `#C1C4C8` | Body copy, secondary text |
| `--color-ink-3` | `oklch(0.595 0.011 255)` ≈ `#7B7F87` | `oklch(0.600 0.010 250)` ≈ `#8D9096` | Tertiary/meta text (dates, counts, labels) |
| `--color-rule` | `oklch(0.855 0.006 250)` ≈ `#D3D4D6` | `oklch(0.315 0.014 255)` ≈ `#3D434D` | Hairline dividers, quiet borders |
| `--color-lime` | `oklch(0.885 0.185 118)` ≈ `#D4EE3D` | `oklch(0.855 0.190 118)` ≈ `#CBE84A` | The one accent: hover fill, selection, active marks |
| `--color-signal` | `oklch(0.520 0.190 258)` ≈ `#3457D5` | `oklch(0.750 0.140 250)` ≈ `#9DB8F5` | Code-syntax keywords only; never in UI chrome |
| `--on-lime` | `oklch(0.185 0.015 255)` ≈ `#1B1F26` | same | Text/icon color *on top of* lime fills |

Dark mode is not a separate palette — it inverts paper/ink lightness and
keeps lime and the ink-scale hue nearly constant. If you add a token, give
it both a light and dark value using this same inversion logic rather than
picking new hues.

**Non-color tokens:**
- Border radius: `0` everywhere. No exceptions, no "just this once for the
  avatar" — even photos are square-cornered (see Components).
- Border weight: `1px solid` for structure (`--color-ink` for strong
  borders, `--color-rule` for quiet ones). `2px` is used only for a few
  playful/game-UI touches (see source) — treat 1px as the default and 2px
  as a rare emphasis, not two general options.
- Box-shadow: not used for elevation, ever. The only `box-shadow` usage in
  the whole system is `inset 0 -1px 0 var(--color-ink-3)` on links — that's
  a hairline underline, not a shadow.
- Motion: `150–200ms ease` on color/background-color transitions only.
  No transforms, no easing curves beyond `ease`, no motion on page load.
  The `wave` keyframe (a small rotate wiggle for an emoji) is the one
  exception, reserved for a single playful accent, not general UI.

## Typography

Two typefaces, loaded from Google Fonts, doing two distinct jobs:

- **Display / headings — "Space Grotesk"** (weights 500/600/700). Used for
  `h1`–`h3`, big numerals, button/badge labels, brand wordmark. Always set
  `letter-spacing: -0.025em` to `-0.045em` (tighter as size increases) and a
  tight `line-height` (1.0–1.25). It never appears in body paragraphs.
- **Body / UI — "Archivo"** (weights 400/500/600, plus italic 400). Used for
  everything else: paragraphs, nav, labels, buttons' surrounding chrome.
  Base body: `15.5px` / `line-height: 1.55`, `font-variant-numeric:
  tabular-nums`, antialiased.

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
<link
  href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Archivo:ital,wght@0,400;0,500;0,600;1,400&display=swap"
  rel="stylesheet"
/>
```

**Prose scale** (rendered long-form content — markdown/CMS bodies):
| Element | Size | Weight | Notes |
|---|---|---|---|
| body `p` | `17px` / `1.72` | 400 | color `ink-2`, not full `ink` |
| `h2` | `clamp(26px, 3vw, 32px)` | 600 | color `ink` |
| `h3` | `clamp(21px, 2.4vw, 26px)` | 700 | `letter-spacing: -0.035em` |
| `h4` | `18px` | 600 | Space Grotesk, not Archivo |
| `blockquote p` | `22px` / `1.25` | 500 | Space Grotesk pull-quote, see below |
| inline `code` | `0.85em` | — | monospace, bordered, `paper-2` bg |

**Page-level hero title:** `clamp(40px, 6vw, 62px)`, weight 700–800,
`line-height: 0.94`, `letter-spacing: -0.045em`, max-width `~13em` so it
wraps like a headline, not a run of prose.

**Labels / eyebrows** — the small uppercase caption used above hero titles,
as section markers, on buttons, and as metadata (dates, counts): `11–13px`,
weight 600, `letter-spacing: 0.08em–0.14em`, `text-transform: uppercase`,
color `ink-3` (or `ink` if it needs to read as active/emphasized).

## The link & hover model (the system's signature)

This is the one interaction pattern to get exactly right — it's what makes
the system read as "this" system rather than generic flat design.

**Default link state:** ink-colored text with a *hairline underline drawn
as an inset box-shadow* (not `text-decoration`, so it can be toggled per
side and doesn't affect line height):
```css
a {
  color: var(--color-ink);
  text-decoration: none;
  box-shadow: inset 0 -1px 0 var(--color-ink-3);
}
```

**Hover state:** the link's background fills solid lime, text flips to
`on-lime`, and the underline (now redundant against a filled block) darkens
to full ink:
```css
a:hover {
  background: var(--color-lime);
  color: var(--on-lime);
  box-shadow: inset 0 -1px 0 var(--color-ink);
}
```

**Text selection** uses the same lime/on-lime pairing (`::selection`), so
highlighting text and hovering a link feel like the same physical action —
that consistency is the point.

**Structural links opt out.** Nav items, buttons, and card links are
*links* in markup but should not get the underline — they set
`box-shadow: none` (Tailwind: `!shadow-none`) and define their own hover
(e.g. a button darkens or fills lime without the underline artifact, a nav
row gets a `paper-3` background instead of lime). The rule: prose links get
the hairline + lime-fill treatment; chrome/navigation links get a bespoke
but still lime-forward hover.

## Components

Recipes below are framework-agnostic (plain HTML/CSS); adapt tag names to
whatever templating the target project uses.

### Button
```html
<button class="btn">Do the thing</button>
<style>
.btn {
  border: 1px solid var(--color-ink);
  background: var(--color-ink);
  color: var(--color-paper);
  padding: 10px 18px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  transition: background-color 150ms ease, color 150ms ease;
}
.btn:hover { background: var(--color-lime); color: var(--on-lime); }
</style>
```
A secondary/outline variant swaps `background: var(--color-ink)` for
`background: transparent; color: var(--color-ink)` and keeps the same
hover. There is no third button style — only filled and outline.

### Label / eyebrow
```html
<p class="label">Section name</p>
<style>
.label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--color-ink-3);
}
</style>
```

### Mark (inline highlight)
Use sparingly — one mark per view, for the single most important word or
status, not for general emphasis:
```html
<span class="mark">New</span>
<style>
.mark { background: var(--color-lime); color: var(--on-lime); padding: 0 6px; }
</style>
```

### Page hero
Eyebrow + oversized title + optional subtitle + a hairline rule closing off
the header from the body:
```html
<header class="page-hero">
  <p class="label">Section</p>
  <h1>An oversized, tightly-tracked headline that can wrap to two lines.</h1>
  <p class="subtitle">One sentence of context, capped to ~34em so it reads as a line, not a block.</p>
</header>
<style>
.page-hero { border-bottom: 1px solid var(--color-ink); padding: 56px 24px 32px; }
.page-hero .label { margin-bottom: 18px; }
.page-hero h1 {
  font-family: "Space Grotesk", system-ui, sans-serif;
  font-size: clamp(40px, 6vw, 62px);
  font-weight: 700;
  line-height: 0.94;
  letter-spacing: -0.045em;
  max-width: 13em;
  color: var(--color-ink);
}
.page-hero .subtitle {
  margin-top: 20px;
  max-width: 34em;
  font-size: 17px;
  line-height: 1.55;
  color: var(--color-ink-2);
}
</style>
```

### Bordered cell grid (tables / card grids without double borders)
The trick: put the border on the *top+left* of the container and
*right+bottom* on each child, so adjacent cells share a single hairline
instead of doubling it up:
```html
<div class="cells">
  <div>Cell A</div>
  <div>Cell B</div>
  <div>Cell C</div>
</div>
<style>
.cells {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  border-top: 1px solid var(--color-ink);
  border-left: 1px solid var(--color-ink);
}
.cells > * {
  border-right: 1px solid var(--color-ink);
  border-bottom: 1px solid var(--color-ink);
  padding: 24px;
}
</style>
```
Use CSS grid, never flexbox, for this pattern — a flex row lets a lone
trailing item stretch to fill the row, which breaks the table illusion.

### Card (e.g. a game/project tile)
```html
<div class="card">
  <div class="card-media" style="background: repeating-linear-gradient(45deg, var(--color-paper-2) 0 10px, var(--color-paper-3) 10px 20px);"></div>
  <div class="card-body">
    <div class="card-head">
      <h2>Title</h2>
      <span class="label">Kind</span>
    </div>
    <p>One or two lines of description.</p>
    <a class="btn" href="#">Go →</a>
  </div>
</div>
<style>
.card { display: flex; flex-direction: column; border: 1px solid var(--color-ink); }
.card-media { aspect-ratio: 4 / 3; border-bottom: 1px solid var(--color-ink); }
.card-body { display: flex; flex-direction: column; gap: 10px; padding: 24px; flex: 1; }
.card-head { display: flex; align-items: baseline; justify-content: space-between; }
</style>
```
There is no photography/illustration layer for card media by default —
placeholder art is a flat repeating hairline pattern (stripes/checks) in
`paper-2`/`paper-3`, not a gradient or stock photo.

### Pull-quote (blockquote)
No fill, no left border-bar (the usual blockquote pattern) — instead
hairline rules top and bottom, and a jump up to the display face:
```css
blockquote {
  border-top: 1px solid var(--color-ink);
  border-bottom: 1px solid var(--color-ink);
  padding: 20px 0;
  margin: 28px 0;
}
blockquote p {
  font-family: "Space Grotesk", system-ui, sans-serif;
  font-weight: 500;
  font-size: 22px;
  line-height: 1.25;
  letter-spacing: -0.025em;
  color: var(--color-ink);
}
```

### Inline code & code blocks
Inline code: monospace, bordered, sits in a `paper-2` well, not a colored
chip. Code blocks: same well treatment at block scale, no radius, no
shadow, with a `highlight.js` theme mapped onto the token scale — keywords
get `--color-signal`, strings a fixed green, numbers a fixed amber,
everything else varying strengths of ink. Full mapping is in `tokens.css`.

### Empty / placeholder state
A dashed `--color-rule` border (the *only* place dashed borders appear —
they mean "not real yet"), generous padding, and the `.mark` label for the
status word:
```css
.empty-state {
  border: 1px dashed var(--color-rule);
  padding: 40px;
}
```

### Images
`1px solid var(--color-ink)` border, `max-width: 100%`, no radius, no
shadow. Portrait/avatar photos additionally get `grayscale` +
`contrast(1.1)` filters to keep photography from introducing color that
competes with lime.

## Layout conventions

- Content sits in a max-width container (`1180px` on this site — adjust to
  taste, but keep it a fixed px value, not a fluid `%`, so line lengths stay
  controlled).
- A fixed-width sidebar (`~244px`) + fluid main content, as a CSS grid
  (`grid-template-columns: 244px minmax(0,1fr)`), not flexbox — collapses to
  a single column with the sidebar becoming a top bar + hamburger below a
  `md` breakpoint (~768px).
- Section padding is consistent and generous:
  horizontal `24px → 40px → 56px` (mobile → tablet → desktop), vertical
  breathing room of `40–56px` above a hero, `40px` above body content.
- Active navigation state: solid `paper-3` background + bold `ink` text (not
  lime — lime is reserved for hover/transient states, not persistent
  "you are here" state). Inactive: `ink-2`, hovers to `ink`.

## Dark mode

Implemented via a `data-theme` attribute on `<html>`, not a `.dark` class,
so it composes cleanly with any framework's own class usage:
```html
<script>
  (function () {
    var t = localStorage.theme ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    document.documentElement.dataset.theme = t;
  })();
</script>
```
Run this inline in `<head>`, before any stylesheet paints, to avoid a
flash of the wrong theme. Persist the user's explicit choice to
`localStorage.theme`; fall back to `prefers-color-scheme` only when unset.

## Checklist for applying this system to a new site

1. Load the two fonts; set body to Archivo, headings to Space Grotesk.
2. Drop in `tokens.css` (or port its custom properties into the target's
   existing CSS/Tailwind setup). Set `border-radius: 0` as the global
   default, not just per-component.
3. Rewrite every existing shadow-based hover/elevation effect as either a
   hairline border or a lime-fill hover — never both a shadow and a border.
4. Audit the palette: exactly one saturated accent color survives (lime, or
   swap the hue if the target brand needs a different one — but keep it to
   one). Remove secondary accent colors from UI chrome; they may survive
   only in code syntax highlighting.
5. Convert primary CTAs to the filled-ink button; secondary actions to the
   outline variant. Delete any third button style.
6. Any tabular/card-grid layout should use the `.cells` shared-hairline
   technique rather than individually-bordered/shadowed cards, unless the
   card explicitly needs to look like a standalone object (e.g. the game
   tile card) — in which case use the full-border `.card` pattern instead.
7. Re-tag metadata text (dates, counts, tags) as uppercase tracked labels
   in `ink-3`, not as small gray text with no tracking.
8. Verify `::selection` and link-hover both resolve to the same lime/
   on-lime pair — this is the detail that sells the system.
