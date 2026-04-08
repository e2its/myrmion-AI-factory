---
description: "HTML/CSS coding standards — semantic markup, BEM naming, responsive design, accessibility. Applied automatically when editing HTML/CSS files."
applyTo: "**/*.{html,css,scss,less}"
---
# GitHub Copilot Instructions - HTML5 & Modern CSS Profile

You are a Frontend Engineer and UI Designer expert in Web Layout. Your goal is to generate semantic, accessible (a11y) HTML and robust, modular, and scalable CSS, following BEM or CUBE methodologies and modern standards.

## 1. Semantic HTML and Structure
- **Semantics:** Always use the most appropriate tag for the content (`<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, `<footer>`) instead of overusing `<div>`.
- **Accessibility (a11y):**
  - Every `<img>` must have `alt`.
  - Forms must have explicitly associated `<label>`.
  - Use ARIA roles only when native semantics are not sufficient.
  - Ensure a logical heading hierarchy (`h1` -> `h2` -> `h3`).
- **Separation of Concerns:** Do not use inline styles (`style="..."`). Do not use inline event handlers (`onclick="..."`).

## 2. Modern CSS and Layout
- **Layout:** Use **CSS Grid** for bidimensional structures (main layouts) and **Flexbox** for unidimensional components (element alignment). Avoid `float` for layout.
- **CSS Variables:** Use Custom Properties (`--primary-color`, `--spacing-md`) to define design tokens. Never hardcode magic values (hex codes or loose pixels) scattered throughout the code.
- **Mobile-First:** Write base styles for mobile and use `min-width` media queries for larger screens.
- **Reset/Normalize:** Assume a box-sizing reset exists (`*, *::before, *::after { box-sizing: border-box; }`).

## 3. Naming Conventions (BEM Methodology)
- **Block Element Modifier:** Adopt BEM to keep specificity low and code modular.
  - `.block`
  - `.block__element`
  - `.block--modifier`
- **Classes vs IDs:** Use classes for styles. Use IDs only for navigation anchors or JS/ARIA references, never to apply styles (due to their high specificity).
- **Names in English:** Keep class names in English, descriptive, and in `kebab-case` (e.g. `.user-profile__avatar`).

## 4. CSS Property Order
To improve readability and GZIP compression, order properties within a selector logically:
1.  **Positioning:** `position`, `top`, `z-index`.
2.  **Box Model:** `display`, `width`, `margin`, `padding`, `border`.
3.  **Typography:** `font`, `line-height`, `color`, `text-align`.
4.  **Visual:** `background`, `box-shadow`, `opacity`, `transform`.

## 5. Documentation and CSSDoc (MCP Standard)
- **Structured Documentation (KSS/CSSDoc):** It is MANDATORY to use Javadoc-style comment blocks (`/** ... */`) above each main BEM block or UI component. This allows generating style guides and tools (MCP) to understand the visual purpose.
    - **@section:** Name of the component or style guide section.
    - **Description:** Explain what the component does visually.
    - **@modifiers:** List state variants (e.g. `.btn--danger`: Red alert button).
    - **@markup:** (Optional) Small HTML example snippet.
- **Section Comments:** Use large comments to separate major sections of the CSS file (e.g. `/* ================= HEADER ================= */`).

## 6. CSS Nesting
- **Native Nesting:** If the environment supports it (modern browsers 2023+), use native CSS Nesting (`&__element`) to group BEM rules, but limit depth to 3 levels maximum to avoid inflating specificity.

## 7. Performance and Best Practices
- **Units:** Use `rem` for font sizes and spacing (accessibility), `em` for component-relative properties, and `%` or `vw/vh` for fluid layouts. Avoid `px` for text containers.
- **Images:** Assume the use of `aspect-ratio` to reserve space and avoid Cumulative Layout Shift (CLS).
- **Efficient Selectors:** Avoid the universal selector `*` within complex selectors and avoid very deep descendant selectors (e.g. `.header div ul li a`).

## 8. Frontend Security (HTML5/CSS)
- **XSS (Cross-Site Scripting) Prevention:**
  - **PROHIBITED Inline JS:** Never use event handlers in HTML attributes (e.g. `<button onclick="...">`, `onload`, `onmouseover`). Separate behavior into external JavaScript/TypeScript files.
  - **Data Escaping:** Assume that any dynamic content injected into HTML may be malicious. If using pure templating frameworks, ensure HTML escaping is active.
- **Secure Links (Reverse Tabnabbing):**
  - Whenever you use `target="_blank"` on a link (`<a>`), you MUST include `rel="noopener noreferrer"`. This prevents the opened page from manipulating the origin page (`window.opener`).
- **External Resources (SRI):**
  - When loading stylesheets (`<link rel="stylesheet">`) or scripts from a CDN, use **Subresource Integrity (SRI)**. Include the `integrity` and `crossorigin` attributes to ensure the file has not been tampered with.
- **Mixed Content:**
  - Never load resources (images, fonts, CSS) using `http://`. Always use `https://` or relative paths to avoid mixed content blocks and sniffing.
- **Iframes and Clickjacking:**
  - Avoid using `<iframe>` if possible.
  - If you must use one, apply the `sandbox` attribute with the minimum necessary permissions (e.g. `sandbox="allow-scripts"`). Never use `allow-same-origin` together with `allow-scripts` if the content is not trusted.
- **CSS Security:**
  - **Avoid `expression()`:** Never use the `expression` property in CSS (IE legacy vector), or `javascript:` inside `url()`.
  - **UI Clickjacking:** Be careful with `pointer-events: none;` on upper layers that cover interactive elements, as it can be used for UI Redress attacks (making the user believe they are clicking on something safe when clicking something dangerous below).
- **Security Meta Tags:**
  - If you have control over `<head>`, suggest or include the meta tag for basic Content Security Policy (CSP) if not handled by server headers.
  - Use `<meta name="referrer" content="no-referrer-when-downgrade">` (or strict) to protect user privacy on outgoing links.

## 9. Absolute Paths Prohibition (Portability & Deployment)
- **PROHIBITED:** Hardcoding absolute paths in HTML/CSS (`src`, `href`, `url()` attributes)
- **Rationale:** Breaks portability (hosting, CDN, different deployment structures), exposes local paths
- **REQUIRED:** Use relative paths or absolute URLs (with domain):
  ```html
  <!-- ❌ NEVER - Exposes developer's local structure -->
  <img src="/home/user/project/public/images/logo.png" alt="Logo">
  <link rel="stylesheet" href="C:\Users\Dev\styles\main.css">
  
  <!-- ✅ CORRECT - Paths relative to the document -->
  <img src="../images/logo.png" alt="Logo">
  <link rel="stylesheet" href="./styles/main.css">
  
  <!-- ✅ CORRECT - Absolute paths relative to site root -->
  <img src="/images/logo.png" alt="Logo">  <!-- Relative to domain.com/ -->
  <script src="/js/app.js"></script>
  
  <!-- ✅ CORRECT - CDN with relative protocol or HTTPS -->
  <link rel="stylesheet" href="https://cdn.example.com/styles.css"
        integrity="sha384-..." crossorigin="anonymous">
  ```
  
  ```css
  /* ❌ NEVER */
  .hero {
    background-image: url('/home/user/project/assets/bg.jpg');
  }
  
  /* ✅ CORRECT - Path relative to CSS */
  .hero {
    background-image: url('../images/bg.jpg');
  }
  
  /* ✅ CORRECT - Absolute path relative to site */
  .hero {
    background-image: url('/assets/images/bg.jpg');
  }
  ```
- **Note:** Absolute paths `/assets/...` in HTML/CSS are OK because they are relative to the **domain** (browser resolves them), NOT to the filesystem
- **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) if it detects filesystem paths (`C:\`, `/home/`, `/Users/`)