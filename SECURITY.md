# Security Policy

## Supported Version

HapCLI is currently a `0.1.x` preview. Security fixes target the latest commit
and the latest published preview release. Older preview builds may not receive
backports.

## Reporting a Vulnerability

Do not disclose a suspected vulnerability in a public issue, discussion, or
pull request.

Use the repository host's private security-advisory feature when available. If
the selected host does not provide private advisories, contact a maintainer
through the private contact method shown on that maintainer's hosting profile
and include only a request for a secure reporting channel at first.

Include the affected version or commit, platform, reproduction steps, impact,
and any proposed mitigation. Remove credentials, personal device identifiers,
and unrelated project data from the report.

The maintainers will acknowledge a complete private report, assess severity,
coordinate a fix, and publish disclosure details after affected users have a
reasonable update path. Preview status is not a reason to publish exploit
details before coordination.

## Security Boundaries

Review tokens are human-confirmation presence gates, not authentication
credentials. HapCLI does not provide sandboxing for external platform tools;
`cjpm`, Gradle, Xcode, DevEco Studio, `hdc`, and downloaded SDK artifacts retain
their own security boundaries. Only use checksummed release assets from a
trusted source.
