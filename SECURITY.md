# Security policy

## Supported versions

Thor is pre-1.0. Only the latest release (and the `master` branch) receives
security fixes.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately
through GitHub: in this repository's **Security** tab, choose **Report a
vulnerability**.

Include what you can of:

- the affected package and version (or commit);
- a minimal reproduction (a page, a request, or a widget tree);
- the impact you expect (for example: HTML or CSS injection, request
  smuggling, a cookie or session weakness, a cache that serves one visitor's
  page to another).

You can expect an acknowledgement within a few days and a status update as the
fix progresses. Once a fix is released, the advisory is published and the
reporter is credited, unless they prefer otherwise.

## Scope

In scope: the packages under `packages/` (`thor_style`, `thor_engine`,
`thor_ui`, `thor_server`, `thor_builder`, `thor_cli`, `thor_lints`,
`thor_studio`, `thor_test`) and the code they generate.

Out of scope: the documentation site and the test apps of this repository
(`apps/`, `test/fixtures/`; they are not meant for production), and vulnerabilities in third-party
dependencies that Thor does not affect (report those upstream).
