# Stirling-PDF — Overview

## What it is

Stirling-PDF is a powerful, open-source PDF editing and processing platform that can be run as a
desktop application, in a browser, or self-hosted on your own servers with a private REST API. It
allows you to edit, sign, redact, convert, merge, split, compress, OCR, and automate PDFs **without
sending documents to any external/third-party service** — all file processing happens on your own
instance.

- **Repository**: https://github.com/Stirling-Tools/Stirling-PDF
- **Documentation site**: https://docs.stirlingpdf.com/
- **Homepage / company**: https://stirling.com
- **API docs**: https://registry.scalar.com/@stirlingpdf/apis/stirling-pdf-processing-api/

## Key features

- **50+ PDF tools** — edit, merge, split, sign, redact, convert, OCR, compress, watermark, rotate,
  page operations, fill forms, compare PDFs, and more.
- **Stateful workspace** — upload once and chain tools together, with full undo/redo history.
- **Runs anywhere** — Docker, bare metal (JAR), Kubernetes, or native desktop apps for Windows,
  macOS, and Linux.
- **Data security** — files are processed by your own instance, never a third-party service.
- **Configurable** — change settings from the in-app UI, or drive everything with environment
  variables and `settings.yml` / `custom_settings.yml`.
- **Automation & integration** — REST API for nearly all tools, no-code pipelines in the UI, folder
  scanning for automated processing, and an MCP server for AI assistants.
- **Enterprise features** — SSO (OAuth2/OIDC and SAML 2.0), user management, permission controls,
  role-based access control, audit logging, and Prometheus metrics.
- **Multi-language support** — interface available in 40+ languages with active translations.
- **Mobile scanner** — scan documents from a mobile device directly into the Stirling instance.

## License

Stirling-PDF is **open-core** (dual-licensed):

- The core application is licensed under the **MIT License** (Copyright (c) 2025 Stirling PDF Inc.).
- Portions of the software that reside under specific directories (`app/proprietary/`, `app/saas/`,
  `engine/`, `frontend/editor/src/proprietary/`, `frontend/editor/src/desktop/`,
  `frontend/editor/src/saas/`, `frontend/editor/src/cloud/`, `frontend/editor/src/prototypes/`,
  `frontend/editor/src/portal/`, `frontend/editor/src/portal-saas/`) are licensed under their own
  respective licenses defined in each directory's `LICENSE` file.
- Content outside of those directories is available under the MIT License.

**Source**: https://github.com/Stirling-Tools/Stirling-PDF/blob/main/LICENSE

### Tiers / modes

Stirling-PDF runs in several modes depending on how it is deployed. The license tier determines user
capacity and which advanced features are unlocked:

| Mode | What it is | Where files are processed | Credits? |
|------|-----------|--------------------------|----------|
| Desktop - Local | Native app, no sign-in | Your device | No |
| Desktop + Stirling.com Cloud | Desktop app signed in to cloud | Mix: local + cloud | Yes (cloud ops) |
| Desktop + Self-hosted server | Desktop app pointed at your server | Your server | No |
| **Web - Self-hosted** | **Docker / K8s / JAR, accessed via browser** | **Your server** | **No** |
| Stirling.com Cloud | Hosted web app at stirling.com/app | Stirling cloud | Yes |

The **free tier** covers up to **5 users**. Beyond 5 users, a paid **Server** (100 users, expandable
in blocks of 100) or **Enterprise** plan is required. Paid plans add official support, SSO, SAML,
audit logging, external database support, and advanced monitoring.

**Source**: https://docs.stirlingpdf.com/Modes%20and%20Licensing/

## Active maintenance status

- **GitHub stars**: ~90.9k (as of research date)
- **Forks**: ~8.2k
- **Commits**: 5,928+
- **Contributors**: 312+
- **Total package downloads**: 904K+ (GHCR)
- **Active development**: Very active. Frequent releases, active issue tracker (376 open issues,
  224 open PRs), active discussions (251).
- **Security advisories**: Maintained and published via GitHub Security Advisories — the project
  actively discloses and patches CVEs (see `security.md` for details).
- **OpenSSF Scorecard**: Tracked via OpenSSF Scorecard badge.
- **Community**: Active Discord server, GitHub Discussions.

The project is under very active, well-funded development (Stirling PDF, Inc. is the corporate
entity behind it) with regular releases and prompt security patching.
