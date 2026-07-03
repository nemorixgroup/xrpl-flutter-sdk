# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in `xrpl_flutter_sdk`
(especially anything related to key generation, signing, or seed
handling), please **do not** open a public issue.

Instead, email: **sdks@nemorixpay.com**

Please include:

- A description of the vulnerability and its potential impact.
- Steps to reproduce, if possible.
- Any suggested fix or mitigation.

We will acknowledge receipt within a reasonable timeframe and keep you
updated as the issue is investigated and resolved.

## Scope

This SDK handles cryptographic key material (secp256k1 and Ed25519 key
pairs, seeds). Given the sensitivity of this code, security reports
related to key derivation, encoding, or signing correctness are treated
as high priority.

## Supported Versions

While the SDK is in `0.x.y-dev` status, only the latest published
version receives security fixes.
