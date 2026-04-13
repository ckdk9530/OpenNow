# OpenNow App Store Connect IAP Checklist

## Scope
- App: `OpenNow`
- Bundle ID: `com.dahengchen.OpenNow`
- IAP type for all three products: `Consumable`
- StoreKit product IDs:
  - `com.dahengchen.OpenNow.tip.1`
  - `com.dahengchen.OpenNow.tip.6`
  - `com.dahengchen.OpenNow.tip.9`

## Exact Product Metadata
### 1. Small
- Reference Name: `OpenNow Support Small`
- Product ID: `com.dahengchen.OpenNow.tip.1`
- Display Name: `Small`
- Description: `One-time support purchase for OpenNow. No features are unlocked.`
- Price: base storefront `United States`, price `0.99 USD`

### 2. Standard
- Reference Name: `OpenNow Support Standard`
- Product ID: `com.dahengchen.OpenNow.tip.6`
- Display Name: `Standard`
- Description: `One-time support purchase for OpenNow. No features are unlocked.`
- Price: base storefront `United States`, price `1.99 USD`

### 3. Generous
- Reference Name: `OpenNow Support Generous`
- Product ID: `com.dahengchen.OpenNow.tip.9`
- Display Name: `Generous`
- Description: `One-time support purchase for OpenNow. No features are unlocked.`
- Price: base storefront `United States`, price `2.99 USD`

## Review Note
Use the same review note on all three IAPs:

`These are optional one-time support purchases for OpenNow, a read-only macOS Markdown reader. They do not unlock content, features, or functionality. The app remains fully usable without purchase.`

## Availability
- Make available in all territories unless there is a business reason to hold back launch.
- If you want review before sale, submit and then set `Remove from Sale`.

## Tax Category
- Leave matched to the parent app unless your accountant says otherwise.
- If nothing custom is set, Apple applies `App Store software` by default.

## App Submission Coupling
- If this is the first IAP for the app, submit these products together with a new app version.
- On the app version page, add all three IAPs in the `In-App Purchases and Subscriptions` section before submitting the build.

## Account Preconditions
- Paid Apps Agreement accepted.
- Banking and tax info complete.
- The App Store Connect user role is at least `App Manager` for submission, or `Developer` to create/edit IAPs.

## Runtime / Build Preconditions
- Xcode target bundle ID matches `com.dahengchen.OpenNow`.
- StoreKit product IDs in code match App Store Connect exactly.
- Test with the local StoreKit file first, then with App Store sandbox/TestFlight.

## Review Risk Notes
- Do not describe these purchases as unlocking features.
- Do not imply that paying changes the reader experience.
- Keep the settings copy consistent with the metadata above.
