## Problem

Describe the user-visible toolchain or workflow problem.

## Change

Describe the bounded behavior changed by this pull request.

## Validation

- [ ] `cjpm build`
- [ ] applicable Cangjie tests
- [ ] `sh -n release/hapup.sh` when release/bootstrap files changed
- [ ] `sh tests/hapup-security.sh` when installer behavior changed
- [ ] `sh tests/public-surface.sh`

## Public Boundary

- [ ] No credentials, personal device identifiers, UDIDs, LAN endpoints, local absolute paths, receipts, or private project data are included.
- [ ] Platform and release claims do not exceed the attached proof.
- [ ] English, Simplified Chinese, and Russian README claims remain aligned when public positioning or platform status changes.
- [ ] Any file, device, network, environment, or workflow mutation is explicit.
