# uptime-bench-certmint

`uptime-bench-certmint` builds and maintains a TLS certificate library for
[`uptime-bench`](../uptime-bench). It is intentionally separate from the
benchmark runtime because it owns ACME account state, DNS-provider credentials,
certbot execution, private-key storage, and issuance-rate policy.

The output is an immutable library of certificate snapshots plus a manifest:

```text
/var/lib/uptime-bench/certs/
  manifest.json
  bench.example.com/
    shortlived/
      20260427/
        slot-00-...
          cert.pem
          chain.pem
          fullchain.pem
          privkey.pem
```

`uptime-bench` should treat this as a read-only input: select a certificate by
SNI/domain and `not_after`, then record the selected manifest entry in the run
output.

## Why This Exists

Public monitoring services need publicly trusted certificates if we want to
test whether they distinguish "expired" from "untrusted CA". Self-signed and
fleet-CA certificates are still useful for deterministic local tests and deep
expiry buckets, but real Let's Encrypt certificates are the right input for
normal WebPKI behavior.

The daemon supports both:

- classic/default Let's Encrypt certificates, normally valid for about 90 days
- the `shortlived` ACME profile, valid for 160 hours

Short-lived certs make near-expiry and newly-expired real-cert coverage
available within days instead of months. Classic certs build the longer-lived
pool over time.

## Rate-Limit Shape

The config should include a unique DNS SAN per issuance, even when the useful
coverage comes from a wildcard. For example:

```text
bench.example.com
*.bench.example.com
cert-20260427-00-shortlived.bench.example.com
```

The extra SAN changes the exact identifier set and avoids repeatedly issuing
the same wildcard set. It does not bypass the registered-domain issuance limit,
so keep total classic + shortlived issuance under the current Let's Encrypt
limits for each registered domain.

## Config

Copy and edit the example:

```sh
cp configs/example.json config.json
```

The example assumes a DNS-01 certbot plugin. Wildcard certificates require
DNS-01 validation. See [docs/operator.md](docs/operator.md) for install steps,
staging verification, production cutover, and systemd setup.

If using the example RFC2136 plugin arguments, copy and edit:

```sh
cp configs/rfc2136.ini.example rfc2136.ini
chmod 600 rfc2136.ini
```

## Commands

Show what is due now:

```sh
go run ./cmd/certmint plan -config config.json
```

Run one issuance pass:

```sh
sudo uptime-bench-certmint once -config /etc/uptime-bench-certmint/config.json
```

Run continuously:

```sh
sudo uptime-bench-certmint daemon -config /etc/uptime-bench-certmint/config.json
```

Preview without running certbot or writing snapshots:

```sh
uptime-bench-certmint once -config config.json -dry-run
```

`once` and `daemon` take an advisory lock at `lock_path`, defaulting to
`<state_dir>/certmint.lock`, so overlapping manual and daemon runs fail fast
instead of racing certificate issuance or manifest writes.

## Certbot

This tool shells out to certbot. It does not reimplement ACME.

For short-lived certificates, certbot is invoked with:

```text
--preferred-profile shortlived
```

For classic certificates, no preferred profile is passed by default so certbot
uses the CA default.

## Security

The library contains private keys. Keep the library directory, certbot config
directory, DNS API credential files, and logs protected with restrictive
permissions. The systemd unit sets `UMask=0077`.
