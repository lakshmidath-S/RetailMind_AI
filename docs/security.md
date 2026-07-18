# Security baseline

RetailMind AI is designed so that voice billing remains fast without exposing shop, customer, or service credentials.

## Current mobile protections

- Android blocks cleartext HTTP with a Network Security Configuration and accepts only system trust anchors.
- Android cloud backup is disabled so future locally cached bill data is not included in device backup by default.
- iOS explicitly keeps App Transport Security enabled; production services must use HTTPS.
- Secrets, certificates, private keys, and local environment files are ignored by Git.
- The mobile application currently has no authentication, persistent bill storage, microphone permission, or network client. Those capabilities must be added together with the controls below.

## Non-negotiable architecture for voice processing

```text
RetailMind mobile app -- HTTPS + authenticated request --> RetailMind backend
RetailMind backend -- server-side API key --> OpenAI transcription API
```

The mobile app must never contain an OpenAI API key, service-role database key, or backend administrative secret. The backend owns all third-party secrets, forwards audio for transcription, and returns only the structured bill result needed by the phone.

## Required controls before real voice integration

1. Authenticate every shopkeeper and authorize access to only that shop's catalogue and bills.
2. Use short-lived user sessions and store session tokens only in platform-secure storage.
3. Send audio only over HTTPS to the project backend; restrict the backend with authentication, rate limits, request-size limits, and per-shop usage limits.
4. Validate transcription-derived data on the server: product IDs must belong to the shop catalogue, quantities must be positive and bounded, and prices must always come from the catalogue/database.
5. Treat a transcription as a draft only. A user must confirm before a sale is recorded or stock changes.
6. Store the minimum required audio and text. Delete raw audio after processing unless the shopkeeper explicitly asks to retain it for support.
7. Log operational events without recording API keys, raw audio, full transcripts, or customer/bill details in diagnostics.
8. Use separate development and production projects, keys, databases, and spending limits. Rotate and revoke any exposed key immediately.

## Future security work

- Add server-side authorization rules for every catalogue, bill, and inventory query.
- Add audit records for bill edits, finalisation, refunds, and stock adjustments.
- Add device/app-integrity checks and abuse detection for the transcription endpoint.
- Define data-retention and deletion controls before production rollout.
- Perform dependency review, secret scanning, and mobile security testing before releasing to shopkeepers.
