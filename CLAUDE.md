KoruBeni Project Architecture Rules
1. OFFLINE FIRST CORE: The emergency call flow must not depend on a developer backend. Optional map tiles, billing, crash SDKs, and platform services may use network; do not claim 100% offline product behavior.
2. AUTHENTICATION: Local PIN ONLY. Biometric unlock (Face/Fingerprint) is STRICTLY FORBIDDEN to prevent duress unlock.
3. RELIABILITY: Must survive Android Doze mode and manufacturer battery optimizations. Must handle denied permissions (Phone, Location) gracefully without crashing. Local error logging only.
4. SCOPE: Do NOT modify UI, theme, or visual designs. Target is Google Play Store.
5. WORKFLOW: Always write a plan and ask for approval before changing actual code.
