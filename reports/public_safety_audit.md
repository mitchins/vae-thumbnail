# Public Safety Audit

Date: 2026-05-19

## Scope

Audit the extracted `VAEThumbnailKit` package for accidental publication of:

- private app credentials
- user or customer data
- private image fixtures
- signing or provisioning assets
- analytics identifiers
- Filmy-specific product logic or internal strategy

## Included In The Public Package

- Swift package source under `Sources/VAEThumbnailKit`
- bundled decoder metadata at `Sources/VAEThumbnailKit/Resources/Model/placeholder_ae_v1.json`
- bundled compiled CoreML decoder at `Sources/VAEThumbnailKit/Resources/Model/placeholder_ae_v1_decoder.mlmodelc`
- payload-only tests under `Tests/VAEThumbnailKitTests`
- example CLI under `Examples/BasicThumbnailCLI`
- package-local scripts, CI workflow, README, license, and reports

## Explicitly Excluded From The Public Package

- Filmy app code outside the narrow thumbnail adapter boundary
- `filmy-service/output/**`
- local sample-thumb caches under `filmy-service/.cache/**`
- research boards, article images, native benchmark fixtures, and other artifacts under `research/placeholders/outputs/**`
- signing config, provisioning state, entitlements outside the Filmy app
- analytics or customer identifiers
- any split-history or private Git history from the Filmy app repository

## Findings

1. No secrets or credentials were copied. The package contains no API keys, auth tokens, signing identities, provisioning profiles, or analytics IDs.
2. No raw images are shipped. Tests and examples use compact base64 payload strings only; no source JPEG/PNG fixtures or cached sample thumbs are included.
3. The public package does not depend on Filmy app types. The package surface is plain Swift plus Apple frameworks; Filmy-specific integration remains in Filmy's thin `AEPlaceholderService` adapter.
4. The bundled model artifact is technically safe from a private-data standpoint, but it does carry a provenance note. The shipped decoder and metadata were generated from the Filmy placeholder research pipeline, which trained on low-resolution Flickr thumbnail derivatives gathered in the private Filmy workspace. The training corpus itself is not redistributed here.
5. The package is a fresh repo. No private app history was copied into `vae-thumbnail`; only new package files and extracted resources are present.

## Residual Risk Note

The main residual risk is not secrecy, but training-data provenance. The model files:

- `Sources/VAEThumbnailKit/Resources/Model/placeholder_ae_v1.json`
- `Sources/VAEThumbnailKit/Resources/Model/placeholder_ae_v1_decoder.mlmodelc/**`

are author-generated artifacts derived from third-party Flickr thumbnail inputs. That provenance is documented and no training images are redistributed, but this is not the same thing as a fully relicensed or owned training corpus.

If a stricter OSS policy is required, replace the bundled model with a decoder retrained on an owned, synthetic, or explicitly licensed dataset before the first public release tag.

## Verdict

Safe to publish with the current code and assets, provided the repo keeps the provenance note above and does not later add raw sample images, caches, or private research outputs.