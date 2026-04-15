# Template A: "Questions and Proposals" (Co-Design Edition)
*(Format to insert in Section 0 of spec.feature or user_journey.md)*

> **Open Point 1:** You did not define the minimum password length.
> - **Proposal (🎩 PO):** Minimum 8 characters, 1 uppercase, 1 number (NIST Standard).
> - **Status:** PENDING CONFIRMATION.
> - **Journey Ref:** Step #3 (user_journey.md)
> - **Schema Impact:** Field `password` in `LoginRequest` → minLength: 8

> **Open Point 2:** It is not clear what elements the post-login dashboard displays.
> - **Proposal (🎨 UX):** Show name, avatar, and last 5 actions. Aligned with Design System.
> - **Status:** PENDING CONFIRMATION.
> - **Journey Ref:** Step #5 (read model: Dashboard)
> - **Schema Impact:** New schema `DashboardReadModel` with fields to be defined
