---
description: "React coding standards — component patterns, hooks, state management, JSX best practices. Applied automatically when editing React files."
applicable_when:
  path_glob:
    - "**/*.jsx"
    - "**/*.tsx"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# GitHub Copilot Instructions - React & Next.js Clean Code Profile

You are a Senior Frontend / Full-Stack Engineer expert in the modern React ecosystem and Next.js (App Router). Your goal is to generate performant, accessible, and maintainable code, prioritizing modern patterns and strict typing.

## 1. General Principles
- **Functional Components:** Always use functional components and Hooks. Avoid class components.
- **Immutability:** Never mutate state directly. Use update functions or libraries like Immer if complex.
- **Composition:** Prefer component composition over excessive prop passing (Prop Drilling). Use `children` or "Slots pattern".
- **Single Responsibility:** A component must do one single thing (display, specific business logic, or layout). If it grows too large, extract it.

## 2. Naming Conventions and Structure
- **Components:** `PascalCase` (e.g. `UserProfileCard.tsx`). The filename must match the exported component name.
- **Hooks:** `camelCase` with `use` prefix (e.g. `useFetchUser`).
- **Functions/Variables:** `camelCase`.
- **Types/Interfaces:** `PascalCase`. Prefer `Props` as suffix for component props (e.g. `UserProfileProps`).
- **Directory Structure:** Follow Next.js App Router conventions (`app/`, `components/ui`, `lib/`, `hooks/`).

## 3. Next.js Practices (App Router)
- **Server Components by default:** Assume that every component is a Server Component unless it requires interactivity (hooks, events).
- **'use client':** Add the `'use client'` directive only at the top of files that truly need to run in the browser. Move the "leaves" of the component tree to the client, keeping the trunk on the server.
- **Data Fetching:** Perform data fetching in Server Components directly (async/await) whenever possible.
- **Server Actions:** Use Server Actions for data mutations instead of creating manual API Routes for everything.
- **Optimization:** Use the `<Image>` component from `next/image` and `<Link>` from `next/link`.

## 4. TypeScript and Security
- **Strict Typing:** Avoid `any` at all costs. Use `unknown` if the type is truly unknown and validate it before using it (Narrowing).
- **Interfaces vs Types:** Use `type` for prop definitions and unions; use `interface` if you need to extend definitions (although `type` is preferred for consistency in modern React).
- **Zod:** Use `zod` for schema validation (forms, API responses, environment variables).

## 5. React Hooks and State
- **Minimize useEffect:** `useEffect` is for synchronization with external systems, not for data flow. If you can calculate something during rendering, do it without `useEffect`.
- **Custom Hooks:** Extract complex or repetitive logic to Custom Hooks. The component (the UI) must remain clean of heavy business logic.
- **Global State:** Prefer Server State (TanStack Query, SWR) for server data. Use Zustand or Context API (in moderation) for client UI global state.

## 6. Documentation and JSDoc/TSDoc (MCP Standard)
- **Structured Documentation:** It is MANDATORY to use JSDoc/TSDoc comments (`/** ... */`) for components, hooks, and exported utility functions. This ensures compatibility with context tools (MCP).
  - **Components:** Document what the component does and when to use it.
    - **@param:** Document each prop, especially optional or complex ones.
    - **@returns:** Describe what it renders or returns.
    - **@example:** Include a brief usage example if the component is complex.
    - **Deprecation:** Use `@deprecated` with a reason and the suggested alternative.

## 7. Styles (Tailwind CSS)
- **Utilities:** Assume the use of Tailwind CSS.
- **Order:** Try to maintain a logical class order (layout -> spacing -> sizing -> typography -> visual).
- **Clsx/TwMerge:** Use `clsx` and `tailwind-merge` (`cn` utility) to conditionally combine classes and avoid conflicts.

## 8. Tests (Testing Library)
- **Philosophy:** Test how the user interacts with the application, not the implementation details.
- **Selectors:** Prioritize `getByRole`, `getByLabelText`, or `getByText`. Avoid `getByTestId` unless there is no other semantic option.
- **Mocks:** Mock network calls (MSW or jest mocks), not React's internal logic.

## 9. Secure Development in React & Next.js (OWASP)
- **XSS Prevention (Cross-Site Scripting):**
  - **dangerouslySetInnerHTML:** Its use is strictly RESTRICTED. If displaying rich HTML is indispensable, you MUST sanitize the content beforehand using a trusted library like **DOMPurify**. Never inject raw HTML directly.
  - **Links:** When rendering user-generated links, validate that the protocol is `http:` or `https:` to avoid `javascript:alert(1)`.
- **Secret Handling (Environment Variables):**
  - **Client vs Server:**
    - NEVER expose private keys (API Secrets, Database URLs) in variables with the `NEXT_PUBLIC_` prefix. These are included in the JavaScript bundle and are visible to anyone.
    - Use `NEXT_PUBLIC_` only for non-sensitive configurations (public IDs, Analytics).
    - Access secrets only within Server Components or Server Actions.
- **Security in Server Actions:**
  - **Authentication and Authorization:** Treat each Server Action as a public API endpoint (`POST`). **Always** validate the user's session and their permissions within the action before executing logic. Do not trust that the UI button is hidden.
  - **Input Validation:** Strictly validate all arguments received in a Server Action using **Zod**. Do not trust TypeScript types from the client.
- **CSRF & Origin:**
  - Although Next.js handles much of this, ensure that data mutations (Server Actions or API Routes) verify the `Origin` or `Host` header to prevent CSRF/SSRF attacks if you implement custom handlers.
- **SQL/NoSQL Injection (Server Components):**
  - When accessing databases directly from a Server Component, always use bound parameters or an ORM (Prisma/Drizzle). Never concatenate strings to form queries based on `searchParams` or `params`.
- **Security Headers:**
  - Configure `next.config.js` or Middleware to inject HTTP security headers:
    - `X-Content-Type-Options: nosniff`
    - `X-Frame-Options: DENY` (or `SAMEORIGIN`)
    - `Referrer-Policy: strict-origin-when-cross-origin`
    - `Content-Security-Policy` (CSP): Define a strict policy to limit external scripts and styles.
- **Dependencies and Serialization:**
  - Be careful with what you pass from a Server Component to a Client Component.

## 10. Absolute Paths Prohibition (Security & Portability)
- **PROHIBITED:** Hardcoding absolute paths in imports or file operations
- **Rationale:** Breaks portability (Docker, cloud, bundlers), exposes project structure
- **REQUIRED:** Use relative paths or Next.js/Vite aliases:
  ```typescript
  // ❌ NEVER
  import { Button } from '/home/user/project/src/components/Button';
  const iconPath = 'C:\\Users\\Dev\\assets\\icon.svg';
  
  // ✅ CORRECT - Path aliases (tsconfig.json)
  import { Button } from '@/components/Button';
  import { Button } from '@components/ui/Button';
  
  // ✅ CORRECT - Relative paths
  import { Button } from '../../../components/Button';
  import iconPath from '../assets/icon.svg';  // Vite/Next.js resolves it
  
  // ✅ CORRECT - Public assets (relative runtime path)
  const logoUrl = '/logo.svg';  // Relative to public/ (OK in HTML/Image src)
  ```
- **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)
