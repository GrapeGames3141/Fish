# Hooked — Android Play + AdMob setup

| Build | Package | Notes |
| --- | --- | --- |
| Play release (AAB) | `com.grapegames.hooked` | Preset `Android Play`, signed with the release keystore |
| Local debug (APK) | `com.tak.castandcrank` | Preset `Android Gate 1 Debug`, unchanged sideload identity |

The two packages are deliberately different so a sideloaded debug build and the
Play build can sit on the same device at once.

## Ad bar — Google test IDs only

Closed testing serves Google's official sample AdMob IDs, so no live ad is ever
requested by a tester:

| Slot | Value |
| --- | --- |
| Android app ID | `ca-app-pub-3940256099942544~3347511713` |
| Bottom banner unit | `ca-app-pub-3940256099942544/6300978111` |

The app ID lives in `project.godot` under `[admob] general/android/app_id` and
is written into `AndroidManifest.xml` by the Poing export plugin. CI can
override it with the `HOOKED_ADMOB_ANDROID_APP_ID` secret. The banner unit is
`AdMobService.TEST_BANNER_AD_UNIT` in
[`src/services/admob_service.gd`](../src/services/admob_service.gd).

The banner is a native `AdPosition.BOTTOM` view: Android owns the bar and the
safe inset, and `game_content_reserve_height()` stays zero. UMP consent runs
before any ad request, and a consent failure closes the banner rather than
falling back to an unconsented request.

**Before leaving closed testing**, replace both IDs with the production AdMob
app ID and banner unit, then declare **Contains ads** on the listing.

## GitHub secrets (required for deploy)

Settings → Secrets and variables → Actions → **Secrets**:

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Release keystore file as base64 |
| `KEY_ALIAS` | Keystore alias (e.g. `grapegames`) |
| `KEYSTORE_PASSWORD` | Keystore password (ASCII only) |
| `SERVICE_ACCOUNT_JSON` | Play API service account JSON |
| `HOOKED_ADMOB_ANDROID_APP_ID` | Optional; defaults to the Google test app ID |

Generate the keystore base64 with:

```bash
base64 -w0 release.keystore | tr -d '\r\n' > keystore.b64
```

## Deploy workflow

[`.github/workflows/deploy-android.yml`](../.github/workflows/deploy-android.yml)

- Triggers on push to `main`/`master` and on **workflow_dispatch**
- Runs the domain test suite, then exports and signs the AAB
- Uploads to the Play **`alpha`** track, which is the Play API name for the
  default **Closed testing** track
- Uploads with `status: draft`, because Play rejects any other status while the
  app has never published a release. **After you roll out the first closed
  testing release from the Console, change that to `status: completed`** in
  `.github/workflows/deploy-android.yml` so later builds reach testers with no
  manual step
- `versionCode` is the GitHub run number and `versionName` is `1.<run number>`,
  so every run is monotonic and Play never rejects a duplicate
- It publishes no GitHub Actions artifact; the AAB only goes to Play

The AAB enables R8 shrinking and keeps native libraries uncompressed for 16 KB
page-size devices, via [`android/play-release.gradle`](../android/play-release.gradle)
and [`android/proguard-godot-play.pro`](../android/proguard-godot-play.pro).
Godot 4.7.1 pins Android Gradle Plugin 8.6.1; do not bump that independently,
it breaks the export template.

## Play Console checklist

- [ ] Create the app `Hooked` and claim package `com.grapegames.hooked`
- [ ] Grant the CI service account **Release manager** on the app
- [ ] Testing → **Closed testing** → create a track and a tester list
- [x] Push to `main` once so CI uploads build 1 to the closed track
- [ ] Console → Closed testing → review the uploaded draft release and **roll it
      out**, which takes the app out of draft state
- [ ] Flip the workflow's `status: draft` to `status: completed` afterwards
- [ ] Copy the closed-testing **opt-in URL** and share it with testers
- [ ] Main store listing: paste [`docs/PLAY_LISTING.md`](PLAY_LISTING.md)
- [ ] Upload `builds/store/hooked/` icon, feature graphic and screenshots
- [ ] App content: privacy policy, **Contains ads = yes**, Data safety, content
      rating, target audience 13+, ads declaration
- [ ] Store settings → Website `https://patguettler.github.io` so AdMob can
      match `app-ads.txt`

Shared Grapegames policy URLs:

- Privacy policy: `https://patguettler.github.io/privacy-policy.html`
- Data deletion: `https://patguettler.github.io/privacy-policy.html#data-deletion`

## Local export

```bash
# Play AAB only
SKIP_DEBUG_APK=1 VERSION_CODE=1 ./scripts/ci/godot-export-android.sh

# AAB plus the sideloadable debug APK
VERSION_CODE=1 ./scripts/ci/godot-export-android.sh
```

The script unzips Godot's `android_source.zip` into `android/build/` (headless
Godot does not install the template on its own), applies the Play gradle
overlay, exports, and then validates the artifact's package name, versionCode
and versionName with Bundletool before it is uploaded. It restores
`export_presets.cfg` and `project.godot` on exit, so a local run leaves no diff.

`ANDROID_HOME` and `ANDROID_SDK_ROOT` must point at the **same** SDK; a
mismatch is the known cause of a Gradle export that dies before an artifact
exists. The tracked marker `android/.build_version` must match `GODOT_VERSION`
(currently `4.7.1.stable`).

## Store art

```bash
python3 tools/make_store_assets.py        # icon, feature graphic, launcher icons
bash tools/capture_store_screenshots.sh   # phone screenshots (needs a display)
```
