# YouBook Design System

## 00_FOUNDATIONS - Token Primitivi

### Gerarchia Design Tokens
Il design system YouBook segue una struttura a tre livelli:
1. **Primitives** - Valori assoluti (colori hex, dimensioni px/rem)
2. **Semantic** - Mapping funzionale dei primitivi
3. **Component** - Token specifici per componenti

---

## Color Tokens

### Brand Colors (Oro/Nero/Bianco SOLO)

#### Primary - Gold
```css
--color-brand-primary: #D4AF37         /* Gold base */
--color-brand-primary-50: #FAF8F0      /* Tint più chiaro */
--color-brand-primary-100: #F5F0DC
--color-brand-primary-200: #EBE1B9
--color-brand-primary-300: #E1D296
--color-brand-primary-400: #D7C373
--color-brand-primary-500: #D4AF37     /* Base */
--color-brand-primary-600: #B8962F     /* Shade più scuro */
--color-brand-primary-700: #8A7123
--color-brand-primary-800: #5C4C18
--color-brand-primary-900: #2E260C
```

**Utilizzo:**
- CTA principali
- Elementi interattivi primari
- Evidenziazioni brand
- Focus states

#### Secondary - Black
```css
--color-brand-secondary: #000000
--color-brand-secondary-foreground: #FFFFFF
```

**Utilizzo:**
- Pulsanti secondari
- Testo su sfondo oro
- Elementi di contrasto

### Neutral Scale (White → Black)
```css
--color-neutral-0: #FFFFFF     /* White puro */
--color-neutral-50: #FAFAFA
--color-neutral-100: #F5F5F5
--color-neutral-200: #E5E5E5
--color-neutral-300: #D4D4D4
--color-neutral-400: #A3A3A3
--color-neutral-500: #737373
--color-neutral-600: #525252
--color-neutral-700: #404040
--color-neutral-800: #262626
--color-neutral-900: #000000    /* Black */
```

**Utilizzo:**
- Backgrounds: 0, 50, 100
- Borders: 200, 300, 400
- Text secondario: 500, 600, 700
- Text primario: 900

### Status Colors (SOLO feedback funzionale)

⚠️ **IMPORTANTE**: I colori di stato NON fanno parte del brand e vanno usati ESCLUSIVAMENTE per:
- Notifiche di sistema
- Stati di validazione form
- Alert/Toast messages
- Indicatori di stato operazioni

```css
/* Success - Verde */
--color-status-success: #22C55E
--color-status-success-light: #86EFAC
--color-status-success-dark: #16A34A

/* Warning - Arancione */
--color-status-warning: #F59E0B
--color-status-warning-light: #FCD34D
--color-status-warning-dark: #D97706

/* Error - Rosso */
--color-status-error: #EF4444
--color-status-error-light: #FCA5A5
--color-status-error-dark: #DC2626

/* Info - Blu */
--color-status-info: #3B82F6
--color-status-info-light: #93C5FD
--color-status-info-dark: #2563EB
```

---

## Typography Tokens

### Font Families
```css
--font-family-base: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif
--font-family-mono: 'SF Mono', Monaco, 'Cascadia Code', 'Courier New', monospace
```

### Type Scale (Major Third 1.250)
```css
--font-size-2xs: 0.625rem    /* 10px */
--font-size-xs: 0.75rem      /* 12px - Caption, small text */
--font-size-sm: 0.875rem     /* 14px - Labels, secondary */
--font-size-base: 1rem       /* 16px - Body text */
--font-size-lg: 1.125rem     /* 18px - Large body */
--font-size-xl: 1.25rem      /* 20px - H4 */
--font-size-2xl: 1.5rem      /* 24px - H3 */
--font-size-3xl: 1.875rem    /* 30px - H2 */
--font-size-4xl: 2.25rem     /* 36px - H1 */
--font-size-5xl: 3rem        /* 48px - Display */
--font-size-6xl: 3.75rem     /* 60px - Hero display */
```

### Font Weights
```css
--font-weight-light: 300      /* Decorativo */
--font-weight-regular: 400    /* Body text */
--font-weight-medium: 500     /* UI elements, labels */
--font-weight-semibold: 600   /* Headings */
--font-weight-bold: 700       /* Emphasis */
```

### Line Heights
```css
--line-height-tight: 1.25     /* Headings grandi */
--line-height-snug: 1.375     /* Headings piccoli */
--line-height-normal: 1.5     /* UI, buttons, labels */
--line-height-relaxed: 1.625  /* Body text, leggibilità */
--line-height-loose: 2        /* Spaziatura extra */
```

### Letter Spacing
```css
--letter-spacing-tighter: -0.05em   /* Display type */
--letter-spacing-tight: -0.025em    /* Large headings */
--letter-spacing-normal: 0em        /* Default */
--letter-spacing-wide: 0.025em      /* Buttons, CTA */
--letter-spacing-wider: 0.05em      /* Labels */
--letter-spacing-widest: 0.1em      /* Overline, tags */
```

### Classi Tipografiche Predefinite

```css
/* Display - Hero sections */
.text-display
font-size: 60px (3.75rem)
font-weight: 700
line-height: 1.25
letter-spacing: -0.05em

/* Headings H1-H6 già configurati in base styles */

/* Body variants */
.text-body-large     /* 18px, regular */
.text-body           /* 16px, regular */
.text-body-small     /* 14px, regular */
.text-caption        /* 12px, regular, muted */
.text-overline       /* 12px, semibold, uppercase, wide spacing */
```

---

## Spacing Tokens

### Scale Base: 4px
```css
--space-0: 0
--space-1: 0.25rem    /* 4px */
--space-2: 0.5rem     /* 8px */
--space-3: 0.75rem    /* 12px */
--space-4: 1rem       /* 16px - Base unit */
--space-5: 1.25rem    /* 20px */
--space-6: 1.5rem     /* 24px */
--space-8: 2rem       /* 32px */
--space-10: 2.5rem    /* 40px */
--space-12: 3rem      /* 48px */
--space-16: 4rem      /* 64px */
--space-20: 5rem      /* 80px */
--space-24: 6rem      /* 96px */
--space-32: 8rem      /* 128px */
```

### Linee Guida Utilizzo

| Token | Utilizzo |
|-------|----------|
| `space-1` | Padding minimo, gap micro |
| `space-2` | Padding icone, gap molto piccolo |
| `space-3` | Padding compatto, gap piccolo |
| `space-4` | **Default padding/gap** - componenti standard |
| `space-6` | Padding generoso, sezioni |
| `space-8` | Margin tra sezioni correlate |
| `space-12` | Margin tra sezioni diverse |
| `space-16+` | Layout spacing, page sections |

---

## Radius Tokens

```css
--radius-none: 0
--radius-sm: 0.25rem      /* 4px - Tags, badges */
--radius-base: 0.5rem     /* 8px - Small components */
--radius-md: 0.75rem      /* 12px - DEFAULT cards, inputs */
--radius-lg: 1rem         /* 16px - Large cards */
--radius-xl: 1.5rem       /* 24px - Modals */
--radius-2xl: 2rem        /* 32px - Hero sections */
--radius-full: 9999px     /* Circular - Avatar, pills */
```

### Default: `--radius: var(--radius-md)` = 12px

**Varianti Tailwind automatiche:**
```css
--radius-sm: calc(var(--radius) - 4px)   /* 8px */
--radius-md: var(--radius)               /* 12px */
--radius-lg: calc(var(--radius) + 4px)   /* 16px */
--radius-xl: calc(var(--radius) + 8px)   /* 20px */
```

---

## Elevation Tokens (Shadows)

### Livelli Standard
```css
--elevation-none: none
--elevation-xs: 0 1px 2px 0 rgba(0,0,0,0.05)
--elevation-sm: 0 1px 3px 0 rgba(0,0,0,0.1), 0 1px 2px -1px rgba(0,0,0,0.1)
--elevation-base: 0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -2px rgba(0,0,0,0.1)
--elevation-md: 0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -4px rgba(0,0,0,0.1)
--elevation-lg: 0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1)
--elevation-xl: 0 25px 50px -12px rgba(0,0,0,0.25)
--elevation-2xl: 0 35px 60px -15px rgba(0,0,0,0.3)
```

### Elevation con Accento Oro
```css
--elevation-gold-sm: 0 2px 8px 0 rgba(212,175,55,0.15)
--elevation-gold-md: 0 4px 16px 0 rgba(212,175,55,0.2)
--elevation-gold-lg: 0 8px 24px 0 rgba(212,175,55,0.25)
```

### Mapping Utilizzo

| Token | Utilizzo | Esempio |
|-------|----------|---------|
| `elevation-none` | Flat design | Sidebar items |
| `elevation-xs` | Hover subtile | Table row hover |
| `elevation-sm` | Card standard | Dashboard cards |
| `elevation-base` | Dropdown, tooltip | Select menu |
| `elevation-md` | Modal, drawer | Side panel |
| `elevation-lg` | Dialog importante | Confirmation modal |
| `elevation-xl` | Overlay massimo | Full-page modal |
| `elevation-gold-*` | CTA premium | Upgrade cards, featured |

---

## Motion Tokens

### Duration
```css
--duration-instant: 0ms       /* No animation */
--duration-fast: 150ms        /* Micro-interactions */
--duration-normal: 250ms      /* Default transitions */
--duration-slow: 350ms        /* Complex animations */
--duration-slower: 500ms      /* Page transitions */
```

### Easing Curves
```css
--easing-linear: linear
--easing-ease: ease
--easing-ease-in: cubic-bezier(0.4, 0, 1, 1)         /* Accelerazione */
--easing-ease-out: cubic-bezier(0, 0, 0.2, 1)        /* Decelerazione */
--easing-ease-in-out: cubic-bezier(0.4, 0, 0.2, 1)   /* Smooth */
--easing-spring: cubic-bezier(0.34, 1.56, 0.64, 1)   /* Elastic bounce */
```

### Transizioni Predefinite
```css
--transition-fast: all var(--duration-fast) var(--easing-ease-out)
--transition-normal: all var(--duration-normal) var(--easing-ease-in-out)
--transition-slow: all var(--duration-slow) var(--easing-ease-in-out)
```

### Linee Guida Animazioni

| Tipo Interazione | Duration | Easing |
|-----------------|----------|--------|
| Hover button/link | `fast` (150ms) | `ease-out` |
| Focus ring | `fast` (150ms) | `ease-out` |
| Dropdown open | `normal` (250ms) | `ease-in-out` |
| Modal appear | `normal` (250ms) | `spring` |
| Page transition | `slow` (350ms) | `ease-in-out` |
| Skeleton loading | `slower` (500ms) | `linear` |

---

## Semantic Token Mapping

### Background
```css
--background: neutral-0          /* Page background */
--background-secondary: neutral-50    /* Section background */
--background-tertiary: neutral-100    /* Nested background */
```

### Foreground
```css
--foreground: neutral-900             /* Primary text */
--foreground-secondary: neutral-700   /* Secondary text */
--foreground-tertiary: neutral-500    /* Tertiary text */
--foreground-muted: neutral-400       /* Disabled/placeholder */
```

### Brand
```css
--primary: brand-primary-500
--primary-hover: brand-primary-600
--primary-active: brand-primary-700
--primary-foreground: neutral-900
--primary-light: brand-primary-100

--secondary: brand-secondary
--secondary-hover: neutral-800
--secondary-foreground: neutral-0
```

### Surface
```css
--card: neutral-0
--card-foreground: neutral-900
--card-hover: neutral-50

--popover: neutral-0
--popover-foreground: neutral-900
```

### Interactive
```css
--muted: neutral-100
--muted-foreground: neutral-600

--accent: brand-primary-100
--accent-foreground: neutral-900
--accent-hover: brand-primary-200
```

### Borders
```css
--border: neutral-300           /* Default border */
--border-strong: neutral-400    /* Emphasized border */
--border-subtle: neutral-200    /* Light border */
```

### Input
```css
--input: neutral-0
--input-background: neutral-50
--input-border: neutral-300
--input-border-focus: brand-primary-500
```

### Focus Ring
```css
--ring: brand-primary-500
--ring-offset: neutral-0
```

---

## Dark Mode

Tutti i token semantici vengono automaticamente remappati in dark mode:

```css
.dark {
  --background: neutral-900
  --foreground: neutral-0
  --card: neutral-800
  --border: neutral-700
  /* ... tutti i semantic token vengono invertiti */
}
```

### Regole Dark Mode
1. **Automatic inversion**: I semantic token si invertono automaticamente
2. **Oro rimane oro**: `--primary` mantiene il gold (#D4AF37) per coerenza brand
3. **Status colors invariati**: Success/Warning/Error/Info restano uguali
4. **Shadows più intensi**: Elevation aumenta opacità per visibilità

---

## Componenti Base - Varianti Size/Density/State

### Button Variants

#### Size
```
sm  - h-8, px-3, text-sm
md  - h-10, px-4, text-base (default)
lg  - h-12, px-6, text-lg
xl  - h-14, px-8, text-xl
```

#### Variant
```
primary   - bg-primary, text-primary-foreground
secondary - bg-secondary, text-secondary-foreground
outline   - border-2, border-primary, text-primary
ghost     - bg-transparent, hover:bg-muted
```

#### State
```
default  - Normal state
hover    - :hover pseudo-class + transition
active   - :active pressed state
disabled - opacity-50, cursor-not-allowed
loading  - opacity-75 + spinner icon
```

### Input Variants

#### Size
```
sm - h-8, px-2, text-sm
md - h-10, px-3, text-base (default)
lg - h-12, px-4, text-lg
```

#### State
```
default  - border-input-border
focus    - ring-2, ring-ring, border-input-border-focus
error    - border-error, ring-error/20
disabled - bg-muted, cursor-not-allowed
```

### Card Variants

#### Elevation
```
flat   - shadow-none
sm     - shadow: elevation-sm
md     - shadow: elevation-base (default)
lg     - shadow: elevation-md
```

#### Padding
```
compact  - p-4
default  - p-6
spacious - p-8
```

---

## Breakpoints (Responsive)

YouBook supporta 3 breakpoint principali:

```css
/* Mobile (default) */
390x844px

/* Tablet */
@media (min-width: 834px) { ... }

/* Desktop */
@media (min-width: 1440px) { ... }
```

### Linee Guida Responsive
- **Mobile-first**: Design default per mobile
- **Progressive enhancement**: Aggiungi complessità per schermi grandi
- **Touch-friendly**: Target touch area minimo 44x44px mobile
- **Density**: Aumenta densità informativa su desktop

---

## Naming Convention

### Pattern: `Role/Area/Component/Variant/State`

Esempi:
```
Admin/Dashboard/StatCard/Default/Default
Staff/Agenda/AppointmentRow/Compact/Hover
Client/Discovery/SalonCard/Featured/Active
Shared/Form/Input/Large/Error
```

---

## Accessibilità (A11Y)

### Contrasto Minimo
- **AA Normal text**: 4.5:1
- **AA Large text**: 3:1
- **AAA Normal text**: 7:1

### Focus Visible
Tutti gli elementi interattivi devono avere:
```css
focus-visible:outline-none
focus-visible:ring-2
focus-visible:ring-ring
focus-visible:ring-offset-2
```

### Color Independence
- Non affidarsi SOLO al colore per trasmettere informazioni
- Usare icone + testo per stati
- Status colors sempre accompagnati da label

---

## Export Figma Tokens (JSON)

```json
{
  "color": {
    "brand": {
      "primary": { "value": "#D4AF37" },
      "secondary": { "value": "#000000" }
    },
    "neutral": {
      "0": { "value": "#FFFFFF" },
      "900": { "value": "#000000" }
    }
  },
  "spacing": {
    "4": { "value": "1rem" }
  },
  "radius": {
    "md": { "value": "0.75rem" }
  }
}
```

---

## Checklist Utilizzo Token

✅ **DO:**
- Usa sempre token CSS variables invece di valori hardcoded
- Usa semantic token (`--primary`) invece di primitives (`--color-brand-primary-500`)
- Usa status colors SOLO per feedback funzionale
- Mantieni dark mode compatibility
- Usa spacing scale (multipli di 4px)

❌ **DON'T:**
- Non usare colori hex direttamente nel codice
- Non creare nuovi colori brand oltre oro/nero/bianco
- Non usare status colors per branding
- Non usare spacing custom (es. `padding: 13px`)
- Non dimenticare stati hover/focus/disabled

---

**Versione:** 1.0.0  
**Ultimo aggiornamento:** 2026-03-03  
**Maintainer:** YouBook Design Team
