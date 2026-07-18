# Phase 5 — Live Legal URL Evidence (2026-07-18)

Scope: read-only fetch of the public GitHub Pages routes at
`2026-07-18 01:11:30 +03`. This proves availability and deployed-content parity
at that time. It does not prove that the URLs have been submitted in Play
Console or that counsel has approved every legal basis.

## Result

All requested routes returned HTTP 200 over HTTPS. Every downloaded response
body was byte-for-byte identical to its repository source.

| Public route | Repository source | Bytes | SHA-256 | Result |
| --- | --- | ---: | --- | --- |
| `/` | `store/privacy_policy.html` | 19,961 | `48e2770632aae7c7b22c51421c8354fb9e6ab8680ea6b13f5fdd47d64d1715a0` | PASS |
| `/privacy_policy.html` | `store/privacy_policy.html` | 19,961 | `48e2770632aae7c7b22c51421c8354fb9e6ab8680ea6b13f5fdd47d64d1715a0` | PASS |
| `/kullanim_sartlari` | `store/kullanim_sartlari.html` | 12,678 | `dcc1e4527471660be18d286d04402f8efe289503434f591f267548529be240b6` | PASS |
| `/kullanim_sartlari.html` | `store/kullanim_sartlari.html` | 12,678 | `dcc1e4527471660be18d286d04402f8efe289503434f591f267548529be240b6` | PASS |
| `/aydinlatma` | `store/aydinlatma_metni.html` | 16,003 | `8c4e63401cc4109c5df5149dd22a2dde4bf6a14100c0cfd23a7b23eec6896cec` | PASS |
| `/aydinlatma.html` | `store/aydinlatma_metni.html` | 16,003 | `8c4e63401cc4109c5df5149dd22a2dde4bf6a14100c0cfd23a7b23eec6896cec` | PASS |
| `/data_deletion.html` | `store/data_deletion.html` | 1,469 | `1c6829c8d88e8a51c7d882579f2c62ed173ce80650f2fccf3518cac3a3773b40` | PASS |

## Repeatable gate

Run immediately before every Play submission:

```text
./scripts/verify_live_legal_urls.sh
```

Any HTTP failure or byte drift is a release stop until the deployed site and
repository source of truth are intentionally reconciled.
