# HapCLI Contracts

This directory contains public, versioned interoperability contracts that can be
consumed independently of the CLI implementation.

Current contract:

- `HAPPUB_NETWORK_DICTIONARY_SCHEMA_V0.yaml`: network dictionary metadata,
  freshness, provider, checksum, and fallback fields.

Runtime JSON envelopes and receipts are emitted by the current CLI and covered
by tests. Additional standalone schemas should be added when an external
consumer needs a stable validation artifact; implementation is not blocked on a
placeholder package split.
