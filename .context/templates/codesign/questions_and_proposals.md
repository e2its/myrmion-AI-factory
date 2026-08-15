# Template A: "Questions and Proposals" (Co-Design Edition)
*(Format to insert in Section 0 of spec.feature or user_journey.md)*

> **Open Point 1:** You did not define the minimum password length.
> - **Proposal (🎩 PO):** Minimum 8 characters, 1 uppercase, 1 number (NIST Standard).
> - **Status:** PENDING CONFIRMATION.
> - **Journey Ref:** Paso 3 (user_journey.md)
> - **Business Field Impact:** field `password` (§ 6): must have at least 8 characters — plain-language rule; ARCH formalises the constraint in design.md § 7.4

> **Open Point 2:** It is not clear what elements the post-login dashboard displays.
> - **Proposal (🎨 UX):** Show name, avatar, and last 5 actions. Aligned with Design System.
> - **Status:** PENDING CONFIRMATION.
> - **Journey Ref:** Paso 5 (user_journey.md)
> - **Business Field Impact:** new § 6 concept for the dashboard summary — fields to be defined in plain language
