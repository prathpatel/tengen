# Releasing Tengen on Google Play

App ID: `org.twostones.tengen` (it can never change once published).

## The upload key

Google Play signs the app for users with its own key (Play App Signing). Builds are uploaded
signed with the **upload key**, `upload-keystore.jks` (alias `upload`), which the owner keeps
with its password, outside the repository. If it is ever lost, request an upload key reset in
Play Console (Setup → App signing).

The build reads it from `android/key.properties`, which git ignores:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Without that file, release builds are signed with the debug key: fine for testing, refused by
Play.

## Building a release

1. Raise `version:` in `pubspec.yaml` (`1.0.1+32`: the number after `+` must grow with every
   upload) and `kAppVersion` in `lib/src/constants.dart`.
2. `flutter analyze` and `flutter test` must pass.
3. `flutter build appbundle --release`
4. Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.

Check the signature with
`jarsigner -verify -verbose:summary build/app/outputs/bundle/release/app-release.aab`: it must
say `Signed by "CN=Tengen, O=Tengen"`.

## Play Console checklist (first release)

- **Create app**: name "Tengen: Play Go (Baduk, Weiqi)", game, free.
- **Privacy policy**: put `store/privacy-policy.html` online (for example at
  `https://twostones.org/tengen/privacy`) and give its address.
- **Store listing**: texts in `store/listing.md`; the 512×512 icon is `assets/icon/icon.png`;
  a 1024×500 feature graphic; at least two phone screenshots.
- **App access**: online features need an online-go.com account. Give reviewers a test OGS
  account (username and password) under "All or some functionality is restricted".
- **Ads**: no ads.
- **Content rating**: a board game; it has user chat (players can talk to each other).
- **Target audience**: 13 and over.
- **Data safety** (the app sends data only to online-go.com, to provide the service, over
  HTTPS):
  - Data collected: *Personal info → User IDs* (the OGS username) and *Messages → Other in-app
    messages* (game chat), both "collected" because they leave the phone for online-go.com,
    required for the app's functionality, not shared with third parties, not used for ads or
    analytics.
  - The password is sent to online-go.com to sign in and not stored by the app.
  - Data is encrypted in transit: yes. Users can ask for deletion: through online-go.com (the
    account is theirs there); local data is deleted by signing out or uninstalling.
  - No location, contacts, photos, files, device IDs, analytics or crash reports.
- **News, government, financial, health**: none.
- **Testing**: personal developer accounts created after November 2023 must run a closed test
  with at least 12 testers for 14 days before applying for production.

## Licences

Tengen is GPL-3.0 (based on the Lichess mobile app); the Learn course, board and stone images
and stone sounds come from online-go.com under the AGPL-3.0 (see COPYING.md). Keep the source
public on GitHub for every published version.
