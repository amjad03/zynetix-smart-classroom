# Production build and keys

Three secrets make a board trustworthy. None of them is in git. Keep them in your password manager or secrets store, with an offline backup. **Losing the Android keystore means existing boards can never receive an app update**: you would have to uninstall and reinstall on every board.

| Secret | File | Used by | Its public half lives in |
|---|---|---|---|
| Android release keystore | `zynetix-release.jks` + `key.properties` | `flutter build apk` (Gradle signing) | the APK signature |
| Pack signing key (Ed25519, id `prod-2026`) | `pack-prod-2026.private.pem` | `pnpm packs` and the API (`PACK_SIGNING_KEY_FILE`, `PACK_KEY_ID=prod-2026`) | `apps/board/assets/packs/trusted-key.json` |
| Licence signing key (Ed25519, id `licence-prod-2026`) | `licence-prod-2026.private.pem` | the API (`LICENCE_KEY_FILE`) | `apps/board/assets/keys/licence-key.json` |

## Build the production APKs

```bash
# 1. Sign the content packs with the production key; this also writes trusted-key.json for the board.
PACK_KEY_ID=prod-2026 PACK_SIGNING_KEY_FILE=/secure/pack-prod-2026.private.pem pnpm packs

# 2. Build release-signed APKs, one per CPU type.
cd apps/board
ZYNETIX_KEY_PROPERTIES=/secure/key.properties flutter build apk --release --split-per-abi
```

`key.properties` holds `storeFile`, `storePassword`, `keyAlias=zynetix` and `keyPassword`. Without it, Gradle falls back to the debug key, which is fine for local testing only.

Check the signature:

```bash
apksigner verify --print-certs app-arm64-v8a-release.apk
```

The SHA-256 certificate digest must be `8c4c01f3fb0ab2bb6cd6eb10ff61f6ad695507ebbc00c7ed55445897bb49306a`.

## API settings

Use the same pack key the APK trusts:

```
PACK_KEY_ID=prod-2026
PACK_SIGNING_KEY_FILE=/secure/pack-prod-2026.private.pem
LICENCE_KEY_FILE=/secure/licence-prod-2026.private.pem
JWT_SECRET=<long random string>
S3_BUCKET=<bucket in ap-south-1>
PUBLIC_API_URL=https://api.<your-domain>
```

## Rotating a key

Packs and licences carry a key id.

1. Add the new public key to the board app. Today the board trusts one pack key and one licence key, so trusting more than one at a time is a small change in `main.dart`.
2. Ship that app update.
3. Then start signing with the new key.
