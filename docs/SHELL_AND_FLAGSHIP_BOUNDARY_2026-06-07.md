# Hap.Pub Shell / Flagship / Commercial Support Boundary

## Decision

HapCLI shell edition must stay thin.

The shell edition is a bootstrap and proof surface for:

- local fixture inspection
- dependency profile switching with restore receipts
- legacy stdx/runtime diagnostics and proof-only stdx get compatibility
- thin runtime download/deploy execution after reviewed flagship plans
- region mirror selection
- plan / apply / history / adoption-pack JSON contracts

It should not keep absorbing richer product responsibilities.

## Product Split

| Layer | Role | Source Strategy | Scope |
|---|---|---|---|
| Shell edition | Thin bootstrap and compatibility probe | Apache-2.0 shell companion | small, inspectable, portable, low dependency |
| Flagship edition | Full HapCLI product implementation | Apache-2.0 open source | typed implementation, richer UX, stronger validation, better package/runtime adapters |
| Commercial support | Support and operations around the open source core | paid service / enterprise support | SLA, hosted dictionary operations, customer-environment integration, migration help, and training |

## Shell Edition Freeze Rule

After stabilization, shell work should prefer:

- bug fixes
- schema stabilization
- smoke coverage
- public-safe demos
- handoff/adoption docs

Shell work should avoid:

- growing a full TOML engine
- becoming a package manager
- building a rich package/runtime database
- owning stdx acquisition governance
- expanding stdx get beyond legacy proof compatibility
- adding long-lived daemon behavior
- adding complex UI
- embedding enterprise policy
- becoming the flagship implementation by accident

## Flagship Edition Direction

The flagship edition can carry the heavier product surface:

- typed command architecture
- structured config parsing
- stronger schema validation
- richer plan/apply ledger
- plugin/adapter system
- network dictionary client
- stdx acquisition planning and provider/checksum/install-root contracts
- package/runtime compatibility matrix
- interactive UX or desktop/cloud integration

The default direction is still open source.

The flagship should not be described as closed-core unless a later explicit decision changes that.

## Commercial Support Boundary

Commercial support may include:

- enterprise onboarding and environment migration
- operating customer-owned compatibility data without withholding public core behavior
- hosted mirror/dictionary operations
- SLA and incident response
- customer-specific package-manager integration work
- CI/cloud integration support
- training and workshops
- managed release verification

Commercial support must not imply:

- the open-source core is intentionally crippled
- public users are denied essential safety features
- Hap.Pub is official ecosystem infrastructure
- HapCLI replaces `cjpm`
- private telemetry or hidden mutation is acceptable
- commercial service exists before it is actually offered

## Public Wording

Safe:

```text
Hapup is a thin Apache-2.0 bootstrap companion. The flagship HapCLI implementation is Apache-2.0 open source, while commercial support may later provide hosted operations, customer-environment integration, training, and SLA-backed services.
```

Avoid:

```text
Shell is the free crippled version.
Flagship is closed source.
Commercial edition owns the real features.
HapCLI is the official package manager.
```

## Next Product Gate

Before adding more shell features, ask:

1. Is this needed to keep the prototype usable or safe?
2. Is this better as a flagship feature?
3. Is this only a commercial support/service concern?
4. Would adding it to shell increase long-term maintenance more than adoption?

If the answer is not clearly shell, implement it in the flagship CLI rather than expanding the bootstrap companion.

## Runtime And Stdx Boundary Update

`stdx` acquisition governance belongs to flagship HapCLI:

- flagship owns `get cangjie-stdx` plan contracts
- flagship owns provider URL, checksum, install-root, and review semantics
- shell must not become the owner of stdx acquisition policy
- shell may provide thin runtime download/deploy execution after a reviewed flagship plan
- shell legacy stdx get behavior is proof/compatibility only and should not grow further
