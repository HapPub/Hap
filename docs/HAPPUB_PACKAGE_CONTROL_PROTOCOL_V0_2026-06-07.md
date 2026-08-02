# Hap.Pub Package Control Protocol V0

## Purpose

This protocol defines how HapCLI can touch package-management responsibilities while staying a compatibility and self-healing control layer.

It is intended for:

- Hap.Pub website projection
- public network dictionary design
- future Action-generated docs or API mockups
- later CLI adapter implementation

## One-Line Contract

HapCLI may coordinate package sources, runtimes, mirrors, and project dependency profiles; it must not claim registry ownership or official package-manager replacement unless that layer is explicitly built and accepted later.

## Object Families

### 1. Toolchain Package Channel

Represents a downloadable toolchain package family.

Examples:

- Cangjie SDK
- Cangjie runtime
- Cangjie stdx
- extended runtime bundle

Minimum fields:

- `channel_id`
- `ecosystem`
- `package_family`
- `version`
- `target`
- `source_url`
- `checksum`
- `checksum_policy`
- `install_shape`
- `receipt_policy`
- `non_promises`

### 2. Source Mirror Profile

Represents project dependency source switching.

Minimum fields:

- `profile_id`
- `region`
- `source_family`
- `dependencies`
- `fallback_order`
- `network_claim`
- `restore_policy`

### 3. Package Manager Adapter

Represents an existing package manager or installer HapCLI may call or guide.

Examples:

- `cjpm`
- `ohpm`
- `pkgsrc-ohos`
- `harmonybrew`
- `vcpkg-ohos`
- direct artifact downloader

Minimum fields:

- `adapter_id`
- `adapter_kind`
- `owned_by_happub`
- `command_surface`
- `allowed_operations`
- `forbidden_operations`
- `dry_run_policy`
- `receipt_policy`
- `sandbox_policy`

### 4. Self-Healing Plan

Represents one repair plan before mutation.

Minimum fields:

- `plan_id`
- `project_type`
- `detected_problem`
- `proposed_actions`
- `mutation_surfaces`
- `backup_policy`
- `restore_command`
- `verification_steps`
- `human_review_required`

### 5. Network Dictionary Manifest

Represents the public dictionary index that a website or CLI can fetch.

Minimum fields:

- `manifest_id`
- `schema_version`
- `generated_at`
- `dictionary_version`
- `entries`
- `ttl_seconds`
- `signature_policy`
- `fallback_policy`
- `cache_policy`

## Capability Strata

| Stratum | Name | Meaning | Public Claim |
|---|---|---|---|
| P0 | Project Config Glue | inspect / switch / restore / doctor | available as preview |
| P1 | Toolchain Package Fetch | runtime / stdx / extension runtime acquisition | preview proof / checksum-gated |
| P2 | Adapter Orchestration | call or guide cjpm / ohpm / pkgsrc / brew-like tools | future adapter lane |
| P3 | Network Dictionary | public mirror and package metadata dictionary | action can prototype |
| P4 | Hap.Pub Package Infrastructure | index, compatibility matrix, recipes, optional registry | future only |

## Edition Boundary

HapCLI has three distinct lanes:

| Lane | Role | Source Strategy | Boundary |
|---|---|---|---|
| Shell edition | thin bootstrap / compatibility probe | Apache-2.0 shell companion | should stop at small diagnostics, receipts, and contract export |
| Flagship edition | full HapCLI product | Apache-2.0 open source | typed implementation, richer validation, adapters, UX, and dictionary client |
| Commercial support | paid support around the open source core | service / enterprise support | SLA, hosted operations, customer-environment integration, training, and migration help |

The shell edition must not become the flagship by accident.

The flagship edition is open source under Apache License 2.0.

Commercial support must not imply that the open-source core is intentionally crippled, that hidden mutation is acceptable, or that Hap.Pub owns official ecosystem authority.

## Public Boundary

Allowed:

- compatibility layer
- self-healing toolchain control
- runtime/stdx package channel
- mirror dictionary
- package-manager adapter
- receipt-backed repair

Blocked:

- official package-manager replacement
- official ecosystem infrastructure
- production package registry claim
- guaranteed mirror availability without monitoring
- silent mutation
- unsigned default download

## Website Projection Hints

The website should make the split visible:

1. Hero:
   - "Self-healing toolchain control for Cangjie/Harmony projects"
2. Problem:
   - local works, CI/cloud fails
3. Control layer:
   - profile / runtime / mirror / receipt
4. Compatibility:
   - works with existing tools
5. Future:
   - package infrastructure may grow from verified dictionaries and adapters

## Network Interface Direction

Action should generate dictionary mockups, not a production API claim.

Suggested endpoints:

- `GET /manifest.json`
- `GET /channels/cangjie-stdx.json`
- `GET /mirrors/source-profiles.json`
- `GET /adapters/package-managers.json`
- `GET /recipes/self-healing-plans.json`

Every response should include:

- `schema`
- `version`
- `generatedAt`
- `data`
- `nonPromises`
