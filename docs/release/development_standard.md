# Development standard

Canonical tracked definition of done (MP-80). This standard is available in a clean checkout.

- Behaviour changes carry meaningful regression tests; emergency-path changes include failure and retry scenarios using fake dispatchers.
- Run the repository analyzer, Flutter tests, critical coverage and relevant native checks.
- **Accessibility** named, not assumed: interactive controls have roles, labels and >=48 dp targets measured with `tester.getRect`; respect reduced motion. Test changed real screens at supported text scales.
- **Error handling and schema**: dispatch failures remain explicit; schema changes carry compatible migrations and tests preserving user data.
- **Rollout**: production changes require the approved candidate evidence and halt procedure in `store/PRODUCTION_ROLLOUT_RUNBOOK.md`. Local test success is not production approval.
- **Rollback**: Play cannot roll back; stop further rollout and roll forward with an increasing versionCode through the gated release path.
- Update CHANGELOG.md for user-visible changes. Preserve offline-first emergency operation and local PIN-only authentication.

Use `scripts/verify_release.sh` after reviewing its arguments and side effects. Smoke evidence does not prove production signing, physical-device acceptance or billing. Report unavailable evidence explicitly; do not lower gates to compensate.
