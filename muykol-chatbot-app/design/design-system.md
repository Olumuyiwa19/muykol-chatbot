# Design System - Faith Motivator Chatbot

## Color Palette

### Primary Colors - Deep Blue (Trust, Peace)
```css
--color-primary-50: #eff6ff;   /* Very light blue backgrounds */
--color-primary-100: #dbeafe;  /* Light blue backgrounds */
--color-primary-200: #bfdbfe;  /* Subtle blue accents */
--color-primary-300: #93c5fd;  /* Medium blue borders */
--color-primary-400: #60a5fa;  /* Interactive blue elements */
--color-primary-500: #3b82f6;  /* Primary brand blue */
--color-primary-600: #2563eb;  /* Primary hover states */
--color-primary-700: #1d4ed8;  /* Primary active states */
--color-primary-800: #1e40af;  /* Dark blue text */
--color-primary-900: #1e3a8a;  /* Darkest blue text */
```

### Secondary Colors - Warm Gold (Hope, Light)
```css
--color-secondary-50: #fffbeb;   /* Very light gold backgrounds */
--color-secondary-100: #fef3c7;  /* Light gold backgrounds */
--color-secondary-200: #fde68a;  /* Subtle gold accents */
--color-secondary-300: #fcd34d;  /* Medium gold borders */
--color-secondary-400: #fbbf24;  /* Interactive gold elements */
--color-secondary-500: #f59e0b;  /* Secondary brand gold */
--color-secondary-600: #d97706;  /* Secondary hover states */
--color-secondary-700: #b45309;  /* Secondary active states */
--color-secondary-800: #92400e;  /* Dark gold text */
--color-secondary-900: #78350f;  /* Darkest gold text */
```

### Accent Colors - Soft Purple (Spirituality)
```css
--color-accent-50: #faf5ff;    /* Very light purple backgrounds */
--color-accent-100: #f3e8ff;   /* Light purple backgrounds */
--color-accent-200: #e9d5ff;   /* Subtle purple accents */
--color-accent-300: #d8b4fe;   /* Medium purple borders */
--color-accent-400: #c084fc;   /* Interactive purple elements */
--color-accent-500: #8b5cf6;   /* Accent brand purple */
--color-accent-600: #7c3aed;   /* Accent hover states */
--color-accent-700: #6d28d9;   /* Accent active states */
--color-accent-800: #5b21b6;   /* Dark purple text */
--color-accent-900: #4c1d95;   /* Darkest purple text */
```

### Neutral Colors
```css
--color-gray-50: #f9fafb;     /* Lightest backgrounds */
--color-gray-100: #f3f4f6;    /* Light backgrounds */
--color-gray-200: #e5e7eb;    /* Subtle borders */
--color-gray-300: #d1d5db;    /* Medium borders */
--color-gray-400: #9ca3af;    /* Placeholder text */
--color-gray-500: #6b7280;    /* Secondary text */
--color-gray-600: #4b5563;    /* Primary text */
--color-gray-700: #374151;    /* Headings */
--color-gray-800: #1f2937;    /* Dark headings */
--color-gray-900: #111827;    /* Darkest text */
```

### Semantic Colors
```css
--color-success-50: #ecfdf5;   /* Success backgrounds */
--color-success-500: #10b981;  /* Success primary */
--color-success-600: #059669;  /* Success hover */

--color-warning-50: #fffbeb;   /* Warning backgrounds */
--color-warning-500: #f59e0b;  /* Warning primary */
--color-warning-600: #d97706;  /* Warning hover */

--color-error-50: #fef2f2;     /* Error backgrounds */
--color-error-500: #ef4444;    /* Error primary */
--color-error-600: #dc2626;    /* Error hover */

--color-info-50: #eff6ff;      /* Info backgrounds */
--color-info-500: #3b82f6;     /* Info primary */
--color-info-600: #2563eb;     /* Info hover */
```

## Typography

### Font Families
```css
--font-primary: 'Inter', system-ui, -apple-system, sans-serif;
--font-heading: 'Playfair Display', Georgia, serif;
--font-mono: 'JetBrains Mono', 'Fira Code', monospace;
```

### Font Sizes
```css
--text-xs: 0.75rem;      /* 12px - Small captions */
--text-sm: 0.875rem;     /* 14px - Secondary text */
--text-base: 1rem;       /* 16px - Body text */
--text-lg: 1.125rem;     /* 18px - Large body text */
--text-xl: 1.25rem;      /* 20px - Small headings */
--text-2xl: 1.5rem;      /* 24px - Medium headings */
--text-3xl: 1.875rem;    /* 30px - Large headings */
--text-4xl: 2.25rem;     /* 36px - Extra large headings */
--text-5xl: 3rem;        /* 48px - Display headings */
```

### Font Weights
```css
--font-light: 300;
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

### Line Heights
```css
--leading-tight: 1.25;    /* Headings */
--leading-snug: 1.375;    /* Subheadings */
--leading-normal: 1.5;    /* Body text */
--leading-relaxed: 1.625; /* Large body text */
--leading-loose: 2;       /* Captions */
```

## Spacing Scale

```css
--space-0: 0;
--space-1: 0.25rem;    /* 4px */
--space-2: 0.5rem;     /* 8px */
--space-3: 0.75rem;    /* 12px */
--space-4: 1rem;       /* 16px */
--space-5: 1.25rem;    /* 20px */
--space-6: 1.5rem;     /* 24px */
--space-8: 2rem;       /* 32px */
--space-10: 2.5rem;    /* 40px */
--space-12: 3rem;      /* 48px */
--space-16: 4rem;      /* 64px */
--space-20: 5rem;      /* 80px */
--space-24: 6rem;      /* 96px */
```

## Border Radius

```css
--radius-none: 0;
--radius-sm: 0.125rem;   /* 2px */
--radius-base: 0.25rem;  /* 4px */
--radius-md: 0.375rem;   /* 6px */
--radius-lg: 0.5rem;     /* 8px */
--radius-xl: 0.75rem;    /* 12px */
--radius-2xl: 1rem;      /* 16px */
--radius-full: 9999px;   /* Fully rounded */
```

## Shadows

```css
--shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
--shadow-base: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
--shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
--shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
--shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
--shadow-2xl: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
```

## Component Specifications

### Buttons

#### Primary Button
```css
.btn-primary {
  background: var(--color-primary-500);
  color: white;
  border: none;
  border-radius: var(--radius-lg);
  font-weight: var(--font-medium);
  transition: all 0.2s ease;
  box-shadow: var(--shadow-sm);
}

.btn-primary:hover {
  background: var(--color-primary-600);
  box-shadow: var(--shadow-md);
}

.btn-primary:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
}

.btn-primary:active {
  background: var(--color-primary-700);
  transform: translateY(1px);
}
```

#### Secondary Button
```css
.btn-secondary {
  background: var(--color-gray-200);
  color: var(--color-gray-800);
  border: none;
  border-radius: var(--radius-lg);
  font-weight: var(--font-medium);
  transition: all 0.2s ease;
}

.btn-secondary:hover {
  background: var(--color-gray-300);
}

.btn-secondary:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(156, 163, 175, 0.3);
}
```

#### Outline Button
```css
.btn-outline {
  background: transparent;
  color: var(--color-primary-500);
  border: 1px solid var(--color-primary-500);
  border-radius: var(--radius-lg);
  font-weight: var(--font-medium);
  transition: all 0.2s ease;
}

.btn-outline:hover {
  background: var(--color-primary-50);
}

.btn-outline:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
}
```

### Input Fields

```css
.input-field {
  width: 100%;
  padding: var(--space-3);
  border: 1px solid var(--color-gray-300);
  border-radius: var(--radius-lg);
  font-size: var(--text-base);
  transition: all 0.2s ease;
  background: white;
}

.input-field:focus {
  outline: none;
  border-color: var(--color-primary-500);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
}

.input-field.error {
  border-color: var(--color-error-500);
}

.input-field.error:focus {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
}
```

### Message Bubbles

#### User Message
```css
.message-user {
  background: var(--color-primary-500);
  color: white;
  padding: var(--space-4);
  border-radius: var(--radius-2xl);
  margin-left: auto;
  margin-right: 0;
  max-width: 75%;
  box-shadow: var(--shadow-sm);
}
```

#### Assistant Message
```css
.message-assistant {
  background: white;
  color: var(--color-gray-800);
  padding: var(--space-4);
  border: 1px solid var(--color-gray-200);
  border-radius: var(--radius-2xl);
  margin-left: 0;
  margin-right: auto;
  max-width: 75%;
  box-shadow: var(--shadow-sm);
}
```

### Modals

```css
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.5);
  z-index: 1000;
}

.modal-content {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background: white;
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-2xl);
  padding: var(--space-6);
  z-index: 1001;
  max-width: 90vw;
  max-height: 90vh;
  overflow-y: auto;
}
```

## Responsive Breakpoints

```css
/* Mobile First Approach */
/* xs: 0px - 475px (default) */

/* sm: 476px - 639px */
@media (min-width: 476px) {
  /* Small phones landscape */
}

/* md: 640px - 767px */
@media (min-width: 640px) {
  /* Large phones */
}

/* lg: 768px - 1023px */
@media (min-width: 768px) {
  /* Tablets */
}

/* xl: 1024px - 1279px */
@media (min-width: 1024px) {
  /* Small desktops */
}

/* 2xl: 1280px+ */
@media (min-width: 1280px) {
  /* Large desktops */
}
```

## Accessibility Guidelines

### Color Contrast
- Normal text: 4.5:1 minimum ratio
- Large text (18px+): 3:1 minimum ratio
- UI components: 3:1 minimum ratio

### Focus Management
- Visible focus indicators on all interactive elements
- Logical tab order
- Focus trapping in modals
- Skip navigation links

### Screen Reader Support
- Semantic HTML structure
- ARIA labels and descriptions
- Live regions for dynamic content
- Alternative text for images

### Keyboard Navigation
- All functionality accessible via keyboard
- Standard keyboard shortcuts
- Escape key closes modals
- Enter/Space activates buttons

## Animation and Transitions

### Timing Functions
```css
--ease-in: cubic-bezier(0.4, 0, 1, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
```

### Durations
```css
--duration-fast: 150ms;
--duration-normal: 200ms;
--duration-slow: 300ms;
```

### Common Transitions
```css
.transition-all {
  transition: all var(--duration-normal) var(--ease-in-out);
}

.transition-colors {
  transition: background-color var(--duration-normal) var(--ease-in-out),
              border-color var(--duration-normal) var(--ease-in-out),
              color var(--duration-normal) var(--ease-in-out);
}

.transition-transform {
  transition: transform var(--duration-normal) var(--ease-in-out);
}
```

## Usage Guidelines

### Do's
- Use primary blue for main actions and branding
- Use secondary gold sparingly for highlights and success states
- Maintain consistent spacing using the scale
- Ensure sufficient color contrast
- Use semantic colors for their intended purposes

### Don'ts
- Don't use more than 3 colors in a single component
- Don't use colors alone to convey information
- Don't create custom spacing values outside the scale
- Don't use animations longer than 300ms for UI feedback
- Don't override focus styles without providing alternatives