# Project Contract

## Purpose

`uptime-bench-certmint` is the certificate-library producer for
`uptime-bench`. It continuously mints publicly trusted certificates using
certbot, snapshots them into an immutable library, and writes a manifest that
the uptime-bench target can consume for TLS expiration scenarios.

## Non-Goals

- It does not run benchmark scenarios.
- It does not serve HTTPS traffic.
- It does not decide monitor scoring.
- It does not replace self-signed or fleet-CA certificate generation for
  deterministic local tests.

## Boundary With uptime-bench

`uptime-bench-certmint` owns:

- ACME/certbot execution
- DNS-01 challenge plugin arguments
- ACME account and lineage state
- issuance cadence
- rate-limit-aware SAN variation
- immutable certificate snapshots
- library manifest generation

`uptime-bench` owns:

- target TLS listener and SNI certificate selection
- scenario activation for `tls_expired`, `tls_expiring`, and `tls_invalid`
- mapping scenario parameters to manifest entries
- recording selected certificate metadata in run output
- scoring monitor results

## Library Manifest

The manifest is JSON at:

```text
<library_dir>/manifest.json
```

Each entry includes:

- domain
- profile label (`classic`, `shortlived`, etc.)
- certbot preferred profile
- UTC slot date and slot index
- SAN identifiers
- certbot cert name
- issuance time
- NotBefore / NotAfter
- SHA-256 fingerprint
- paths to `cert.pem`, `chain.pem`, `fullchain.pem`, and `privkey.pem`

Consumers should not parse directory names for behavior. Directory names are
for operator readability; `manifest.json` is the contract.

## Issuance Strategy

Use a low, steady cadence per domain:

- classic/default profile: build the long-lived pool
- shortlived profile: quickly create soon-to-expire and expired real certs

Each planned issuance adds a unique SAN from the configured template. This keeps
wildcard coverage while avoiding the exact-set duplicate certificate limit.

The daemon spreads `per_day` issuance across UTC day slots. If it starts late,
it catches up on due slots for that UTC day.

## Initial uptime-bench Integration Tasks

1. Add TLS listener and SNI support to the target binary.
2. Add a cert-library loader that reads `manifest.json`.
3. Add selection logic for:
   - closest `not_after` to requested `days_remaining`
   - expired cert closest to requested `days_expired`
   - fallback to fleet-CA generated certs when no public cert exists
4. Record manifest entry ID/fingerprint/not_after in ground-truth details.
