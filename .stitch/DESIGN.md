---
name: Workbench Devtools
colors:
  surface: '#101418'
  surface-dim: '#101418'
  surface-bright: '#363a3e'
  surface-container-lowest: '#0b0f12'
  surface-container-low: '#181c20'
  surface-container: '#1c2024'
  surface-container-high: '#262a2f'
  surface-container-highest: '#31353a'
  on-surface: '#e0e3e8'
  on-surface-variant: '#c3c6d6'
  inverse-surface: '#e0e3e8'
  inverse-on-surface: '#2d3135'
  outline: '#8d909f'
  outline-variant: '#434654'
  surface-tint: '#b4c5ff'
  primary: '#b4c5ff'
  on-primary: '#002a77'
  primary-container: '#275acf'
  on-primary-container: '#d6deff'
  inverse-primary: '#2156cb'
  secondary: '#b0c6ff'
  on-secondary: '#022d6f'
  secondary-container: '#274689'
  on-secondary-container: '#9bb7ff'
  tertiary: '#ffb872'
  on-tertiary: '#4a2800'
  tertiary-container: '#8c5515'
  on-tertiary-container: '#ffd7b4'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea7'
  secondary-fixed: '#d9e2ff'
  secondary-fixed-dim: '#b0c6ff'
  on-secondary-fixed: '#001946'
  on-secondary-fixed-variant: '#244486'
  tertiary-fixed: '#ffdcbf'
  tertiary-fixed-dim: '#ffb872'
  on-tertiary-fixed: '#2d1600'
  on-tertiary-fixed-variant: '#6a3c00'
  background: '#101418'
  on-background: '#e0e3e8'
  surface-variant: '#31353a'
  accent-soft-light: '#eaf0ff'
  accent-soft-dark: '#27344b'
  surface-paper-light: '#ffffff'
  surface-paper-dark: '#20262b'
  border-line-light: '#dde2e7'
  border-line-dark: '#39434b'
  text-ink-light: '#232a30'
  text-ink-dark: '#ecf0f1'
  text-muted-light: '#616c75'
  text-muted-dark: '#aab6be'
  status-busy: '#275acf'
  status-busy-dark: '#98b5ff'
  status-retry-amber: '#8c5515'
  status-retry-amber-dark: '#edc388'
  status-retry-bg-light: '#fff5e5'
  status-retry-bg-dark: '#392f22'
  status-error-crimson: '#a93939'
  status-error-crimson-dark: '#ffb1ac'
  status-error-bg-light: '#fff0ee'
  status-error-bg-dark: '#3b2828'
  status-idle: '#616c75'
  status-idle-dark: '#aab6be'
typography:
  headline-lg:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.6px
  headline-md:
    fontFamily: Manrope
    fontSize: 19px
    fontWeight: '600'
    lineHeight: 25px
  headline-sm:
    fontFamily: Manrope
    fontSize: 17px
    fontWeight: '500'
    lineHeight: 22px
  title-brand:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '650'
    lineHeight: 21px
    letterSpacing: -0.4px
  body-default:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 21px
  body-composer:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-code:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-code-block:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 20px
  label-meta:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-role:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.9px
  label-badge:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
  label-kbd:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1px
  gutter-split: 12px
  margin: 1rem
  margin-screen: 1.5rem
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

The design system establishes a high-density, professional developer interface optimized for Android tablet landscape workflows with attached hardware keyboards. It conveys calm mechanical precision, uncompromising reliability, and deep focus. The aesthetic deliberately strips away non-functional decoration, skeuomorphic gloss, and synthetic elevation in favor of a utilitarian, border-segmented cockpit.

The visual style merges modern technical minimalism with IDE desktop ergonomics:
- **Hairline architecture:** Surfaces and zones are partitioned by precise 1px borders rather than diffuse drop shadows.
- **Dual-pane harmony:** The canvas is anchored by a persistent split view—giving primary focus (2/3) to conversational development, code review, and execution logs, paired alongside a real-time responsive emulator preview (1/3).
- **Keyboard-first ergonomics:** High hit density, inline shortcut affordances (`Ctrl + Enter`, key hints), compact typography, and immediate visual state transitions designed for power users operating with physical inputs or precision touch.

## Colors

The color system operates via modern CSS `light-dark()` values to preserve parity across daylight and low-light engineering environments, defaulting to dark mode for reduced glare during sustained coding sessions.

### Functional Roles
- **Primary & Interactive (`#275acf` / `#98b5ff`):** Signals active focus, selected tabs, interactive action hover states, and live agent "busy" activity dots.
- **Surface Canvas (`#f4f5f6` / `#15191d`):** The structural backdrop hosting the main dual-pane workbench frame and the bare hardware emulator canvas.
- **Surface Paper (`#ffffff` / `#20262b`):** Interior workspace cards, active tab plates, floating toolbars, and the prompt composer bar.
- **Borders & Dividers (`#dde2e7` / `#39434b`):** 1px structural lines that partition toolbars, navigation rails, chat message rows, and emulator split gutters.
- **Status Amber (`#8c5515` / `#edc388` with `#fff5e5` / `#392f22` fill):** Highlights retry loops, build warnings, and agent clarification requests.
- **Status Crimson (`#a93939` / `#ffb1ac` with `#fff0ee` / `#3b2828` fill):** Designates runtime exceptions, execution test failures, and connection timeouts.

## Typography

Typography prioritizes density and visual discrimination across natural language dialogue and code constructs:
- **Headlines & Workspace Titles (Manrope):** Geometric, solid structure delivering clean screen titles and workspace headings without consumer roundness.
- **Body & Dialogue (Inter):** Highly legible, neutral workhorse engineered for terminal logs, agent prompt responses, and dense tabular data.
- **Paths, Shortcuts & Code (JetBrains Mono):** Monospaced type for all file paths (`.path`), command tokens, diff traces, and keyboard cues (`<kbd>`).
- **Touch Input Protection:** The composer input uses 16px body sizing to prevent automatic touch viewport zooming on mobile and tablet WebKit engines.
- **Section Role Markers:** Overline metadata labels (`.role`) use 11px uppercase styling with `0.9px` tracked spacing to cleanly delineate user inputs from agent turns.

## Layout & Spacing

### 2/3 and 1/3 Workspace Grid
The core layout is designed specifically for landscape tablet workstations:
- **Landscape Layout Ratio:** The viewport divides into a strict dual-column grid (`grid-template-columns: minmax(0, 2fr) minmax(240px, 1fr)`). The primary 2/3 pane holds the session tab bar, agent chat transcript, and composer. The secondary 1/3 pane houses the live emulator viewport with top-aligned device controls.
- **No Decorative Bezel on Emulator:** The device preview surface renders flush without a faux chassis frame, maximizing pixel real estate while maintaining fixed aspect ratios.
- **Breakpoints:**
  - `Tablet Landscape (> 700px):` Persistent 2/3 vs. 1/3 dual-column arrangement. Min height is 568px.
  - `Compact / Split Tablet (421px – 700px):` Adjusted ratio `minmax(0, 1.6fr) minmax(155px, 1fr)`. Padding contracts from 24px to 16px.
  - `Single Column Portrait (<= 420px):` Stacks vertically with the emulator sliding below the session workspace.
- **Component Touch Targets:** Buttons and interactive touch nodes enforce a minimum 44px hit-box whenever `(pointer: coarse)` is active.

## Elevation & Depth

Visual hierarchy is communicated through planar separation, tonal layering, and hair-thin borders rather than floating shadows:
- **Tonal Planes:** Surface layers step forward using subtle background shifts: Canvas (`--bg`) sits furthest back, Cards and active panels (`--paper`) sit one plane forward, and interactive hover planes use tinted blue washes (`--soft`).
- **Structural Outlines:** All panel boundaries, navigation headers, and list divisions use crisp `1px solid var(--border-line-*)` rules.
- **Micro Shadows for Sliders & Toggles:** Small interactive physical elements (e.g., switches, split dragging handles) use a subdued micro shadow (`0 1px 2px -1px rgba(0, 0, 0, 0.12)`).
- **Transient Overlays:** Popovers, contextual file dropdowns, and Floating UI tooltips use soft ambient drops (`0 4px 12px rgba(0, 0, 0, 0.16)`) with high-contrast hairline perimeter strokes.

## Shapes

The design system uses deliberate, mixed corner radii calibrated to component size:
- **0px (Sharp):** Emulator preview screen, dividing lines, code gutter panels, and full-bleed table cells.
- **4px (`--radius-sm`):** Inline code chips (`code`), status badge lozenges, and standard checkbox elements.
- **8px (`--radius-lg`):** Standard workbench buttons, file tabs, and warning notice banners.
- **11px – 12px:** Chat message prompt composer card.
- **16px (`--radius-2xl`):** Outer workbench container shells and tablet modal cards.
- **9999px (Pill):** Status indicator dots, filter selection tags, and horizontal device carousel toggles.

## Components

### Buttons
- **Default / Secondary:** 8px radius, `1px solid var(--border-line)`, background `var(--surface-paper)`, text `var(--text-ink)`. Hover shifts background to `var(--accent-soft)`.
- **Primary Action (`.send`):** Background `var(--text-ink)`, text `var(--surface-paper)`, hover switches background to `var(--primary)`. Minimum height 36px (scales to 44px on coarse pointers).
- **Ghost:** Transparent background with no border, using `var(--text-muted)` text that shifts to `var(--text-ink)` on hover.

### Tabs Bar
- Horizontally scrollable strip, zero vertical divider bleeding.
- **Active Tab:** Solid background `var(--surface-paper)`, top and side border `1px solid var(--border-line)`, bottom border flush with active surface, active blue text indicator (`#275acf` / `#98b5ff`). Includes a discrete 14px close glyph.
- **Inactive Tab:** Transparent background, `var(--text-muted)` label, subtle hover highlight.

### Status Badges
Compact 4px rounded lozenges displaying execution and connection states:
- **Idle:** Neutral gray outline and dot (`#616c75`), subtle background.
- **Busy:** Soft accent background (`#eaf0ff` / `#27344b`), blue dot (`#275acf` / `#98b5ff`), pulsing animation.
- **Retry / Warning:** Amber surface (`#fff5e5` / `#392f22`), text and icon in warning amber (`#8c5515` / `#edc388`).
- **Error / Attention:** Crimson surface (`#fff0ee` / `#3b2828`), text and icon in crimson (`#a93939` / `#ffb1ac`).

### Input Fields & Message Composer
- **Textarea Composer:** 11px rounded container with 1px border. Background set to `var(--surface-paper)`. Includes integrated bottom action row holding keyboard hint (`Ctrl + Enter`), model selector, and send action button.
- **Code Inputs & Paths:** Rendered in monospace with overflow-wrap, subtle inset padding, and muted border.

### Emulator Preview Panel
- Flush edge presentation occupying 1/3 width of the workspace.
- Top control header features device switcher pills (Phone, Foldable, Tablet) with smooth horizontal scroll and quick refresh (`rotate-cw`) controls.
- Content body dynamically scales the application preview while preserving target device aspect ratios.
