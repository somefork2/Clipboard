# Mac App Store release checklist

What the code now does, and what only you can do. Everything under "Still yours"
requires an Apple Developer account, a domain, or a decision — none of it can be
committed to the repository.

## Done in this repository

- Xcode project (`project.yml` → `xcodegen generate`) with App Sandbox, Hardened
  Runtime and automatic signing. The Swift package alone can never produce an
  App Store binary.
- `Sources/Resources/ClipStack.entitlements`: sandbox, network client (StoreKit),
  user-selected files, CloudKit container, keychain group.
- `Sources/Resources/PrivacyInfo.xcprivacy`: required-reason declarations for
  `UserDefaults`, file timestamps and disk space. Without this the upload is
  rejected automatically.
- `Info.plist`: `LSApplicationCategoryType`, copyright, `ITSAppUsesNonExemptEncryption`,
  icon name, Services entries.
- App icon at all ten required sizes (`Tools/make-icon.swift` regenerates it).
- StoreKit 2: real products, real prices, `Transaction.updates` listener,
  entitlement derived from `Transaction.currentEntitlement`, **Restore Purchases**,
  manage-subscription link, renewal terms and legal links on the purchase screen.
- `Products.storekit` wired to the Run scheme for local testing.
- Every feature advertised on the paywall is implemented. Nothing is sold that
  does not work.

## Still yours

### 1. Identifiers and signing

- [ ] Set `DEVELOPMENT_TEAM` in `project.yml`.
- [ ] Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.clipstack.app` to your own
      reverse-domain identifier, then regenerate the project.
- [ ] Register the App ID with App Sandbox, iCloud and In-App Purchase enabled.
- [ ] Turn on the iCloud capability with CloudKit in Xcode (Signing &
      Capabilities ▸ + Capability ▸ iCloud ▸ CloudKit) and let it create the
      container `iCloud.<your bundle id>`. That is the whole CloudKit setup.

      **No schema work is needed.** Sync uses a custom record zone and server
      change tokens rather than queries, so there are no record types, fields or
      indexes to define in the CloudKit console. The zone, the record type and
      its fields are created automatically the first time the app saves a clip.

- [ ] Before submitting, run the app once while signed into iCloud so the schema
      exists in the Development environment, then open the CloudKit console and
      press **Deploy Schema Changes** to copy it to Production. Development and
      Production are separate databases, and the App Store build only ever talks
      to Production. This is one button; it is the only console step.

### 2. In-app purchases

- [ ] Create the subscription group **ClipStack Pro** with
      `com.clipstack.pro.monthly` and `com.clipstack.pro.annual`
      (rename to match your bundle prefix and update `SubscriptionManager`).
- [ ] Add an introductory free trial if you want one. The UI shows a trial only
      when StoreKit reports one — it never claims a trial that does not exist.
- [ ] Fill in localised display names and descriptions; the paywall renders them.
- [ ] Upload a subscription review screenshot and a review note explaining how to
      reach the paywall.

### 3. Legal (blocking)

- [ ] Host a privacy policy and put its URL in `LegalLinks.privacyPolicy`
      (`Sources/Views/PaywallView.swift`) **and** in App Store Connect.
- [ ] Terms of use: the standard Apple EULA is already linked; replace it if you
      use your own.
- [ ] Host a support page and set `LegalLinks.support`.
- [ ] App Privacy questionnaire: ClipStack collects nothing. Clipboard contents
      stay on device, or in the user's own private CloudKit database. Say exactly
      that.

### 4. Review notes to include

Reviewers reject clipboard managers when they cannot tell why Accessibility is
requested. Say it plainly in the review notes:

> ClipStack asks for Accessibility access only to synthesise the ⌘V keystroke so
> the clip the user selects is pasted into the app they were using. It does not
> read other apps' contents. The permission is optional — with "Paste directly
> into the active app" off, ClipStack only writes to the system pasteboard.

Also mention that the Services entries appear under the Services submenu and how
to enable them.

### 5. Store listing

- [ ] Screenshots at 2880×1800 (the palette, the history window, the menu bar,
      the paywall).
- [ ] Description that matches the feature list exactly — mismatches are the most
      common rejection for subscription apps.
- [ ] Keywords, support URL, marketing URL.
- [ ] Age rating, export compliance (already declared exempt in `Info.plist`).

## Testing before submission

- [ ] Purchase, cancel, expire and restore against `Products.storekit`.
- [ ] Sandbox account purchase on a clean machine.
- [ ] Launch with Accessibility denied: pasting must degrade to "copied to
      clipboard", never fail silently.
- [ ] Launch with no iCloud account: sync must report it, not hang.
- [ ] Copy from a password manager: nothing may be recorded.
- [ ] Fill history past the free limit: oldest clips drop, no modal storm.
- [ ] Quit and relaunch: duplicates must not reappear (stable SHA-256 hashing).
