# Task-066 GitHub-Only Prerelease Monitor

**Date:** 2026-06-20  
**Monitor Agent:** Reasonix  
**Role:** monitor-github-only-final-evidence  
**Review Owner:** Codex

---

## Reading Scope

- GitHub Releases API for `v2.0.10-task066-task074-candidate` (baseline +5169) and `task066-plus5169-github-only.27868385432` (new prerelease)
- GitHub Actions API for runs:
  - CI run 27868372344
  - Build run 27868385432
  - Release APK runtime smoke run 27868701836
- Local git for commit count, commit diff, and product-code verification (read-only)
- No APK downloads, no local Flutter/Dart/Java/Gradle commands

---

## Factual Findings

### 1. Baseline +5169 Prerelease

| Field | Value |
|---|---|
| Tag | `v2.0.10-task066-task074-candidate` |
| Target commit | `465952d9c0f64b708dec08dbc6c94e236773ad31` |
| Prerelease | true |
| Draft | false |
| Build run | 27833501793 (per release body) |
| Version string | `2.0.8-465952d9c+5169` |

**APK Assets:**

| APK | Size (bytes) | SHA-256 Digest |
|---|---|---|
| `PiliAvalon_android_2.0.8-465952d9c+5169_arm64-v8a.apk` | 25,956,823 | `sha256:95fd2d1008abb0e740cd888918d17ab9f192029d349282562d42241c4c29b69a` |
| `PiliAvalon_android_2.0.8-465952d9c+5169_armeabi-v7a.apk` | 25,879,356 | `sha256:b2c4b4a278fc4bea5b027101e6de109a1af3761bd8985d0620e166dde7a71dd0` |
| `PiliAvalon_android_2.0.8-465952d9c+5169_x86_64.apk` | 26,947,610 | `sha256:ddf608e22b3cc9ed53be5b40a0743d107cce20d1c52baa99c599e5e5f3863a92` |

**Signing Fingerprint (from release body):** `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

All 3 APK names include `+5169`.

---

### 2. New Coordination Commit

| Field | Value |
|---|---|
| SHA | `12ba24aa292e33369779fd2880cc959d2d8fa818` |
| Commit count (git rev-list) | **5170** (+1 from 5169) |
| Commit message | `Record task066 plus5169 GitHub baseline` |

**Product code diff vs baseline (465952d9c..12ba24aa, excluding `records/`):**

_No output — zero diff lines._

**Full diff (including records/):**

```
records/reasonix/task-066/github-only-plus5169-baseline-2026-06-20.md    | 34 +++++++++++
records/reasonix/task-066/2026-06-20-task066-github-only-prerelease-monitor.md | 67 ++++++++++++++++++++++
2 files changed, 101 insertions(+)
```

- **Product code is unchanged from +5169.** Only 2 records files were added.
- Commit count 5170 confirmed.

---

### 3. CI Run 27868372344

| Field | Value |
|---|---|
| Name | PiliAvalon CI |
| Head SHA | `12ba24aa292e33369779fd2880cc959d2d8fa818` |
| Branch | `task-066-detail-intro-shielding` |
| Status | completed |
| Conclusion | **success** |
| Created | 2026-06-20T10:27:16Z |
| Updated | 2026-06-20T10:39:11Z |

**Job Conclusions:**

| Job | Conclusion | Duration |
|---|---|---|
| Focused Flutter verification | success | ~2m16s |
| Build Android x86_64 artifact | success | ~5m58s |
| Android emulator runtime smoke | success | ~3m38s |

All 3 jobs passed. Key verification steps include: shielding tests, settings model test, recommend settings test, bootstrap startup test, `flutter analyze --no-fatal-infos`, x86_64 APK build, and emulator install+launch smoke.

---

### 4. Build Run 27868385432

| Field | Value |
|---|---|
| Name | Build |
| Head SHA | `12ba24aa292e33369779fd2880cc959d2d8fa818` |
| Branch | `task-066-detail-intro-shielding` |
| Status | completed |
| Conclusion | **success** |
| Created | 2026-06-20T10:27:50Z |
| Updated | 2026-06-20T10:35:15Z |

**Job Conclusions:**

| Job | Conclusion |
|---|---|
| Release Android | success |
| win_x64 | skipped |
| ios | skipped |
| linux_x64 | skipped |
| mac | skipped |

Release Android job produced APKs, captured signing fingerprints, and created the prerelease. Non-Android platforms skipped (expected for mobile-only APK release).

---

### 5. New Prerelease: `task066-plus5169-github-only.27868385432`

| Field | Value |
|---|---|
| Tag | `task066-plus5169-github-only.27868385432` |
| Target commit | `12ba24aa292e33369779fd2880cc959d2d8fa818` |
| Prerelease | true |
| Draft | false |

**APK Assets:**

| APK | Size (bytes) | SHA-256 Digest |
|---|---|---|
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_arm64-v8a.apk` | 25,957,159 | `sha256:8e5a58da3e2f4ae699223e6c4716dfd61f1fb2b666b428f35f0cc26d922e83cf` |
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_armeabi-v7a.apk` | 25,879,295 | `sha256:ac77375f4ad5569b5cfd572165b821cc293979b7585e07d032d98fa029abafd6` |
| `PiliAvalon_android_2.0.8-12ba24aa2+5170_x86_64.apk` | 26,948,050 | `sha256:9f2b6b0b067e6ddfa2e98a94af757c5dbbd17cd5bf25f2ae179b30a5956bc9d2` |

**Signing Fingerprint (from release body):** `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`

- All 3 APK names include `+5170`.
- **Signing fingerprint matches baseline exactly.**
- APK sizes are within ~300 bytes of baseline (expected: only version string differs).

---

### 6. Release APK Runtime Smoke Run 27868701836

| Field | Value |
|---|---|
| Name | Android Runtime Smoke |
| Head SHA | `12ba24aa292e33369779fd2880cc959d2d8fa818` |
| Branch | `task-066-detail-intro-shielding` |
| Status | completed |
| Conclusion | **success** |
| Created | 2026-06-20T10:41:45Z |
| Completed | 2026-06-20T10:44:24Z |
| Duration | ~2m39s |

**Job: Install and launch APK on emulator — success**

All 9 steps passed:
1. Set up job ✓
2. Checkout ✓
3. Download x86_64 APK artifact ✓
4. List downloaded APK ✓
5. Enable KVM for emulator ✓
6. Android emulator install and launch smoke ✓
7. Upload runtime smoke evidence ✓
8. Post Checkout ✓
9. Complete job ✓

---

## Verification Results

| Check | Result |
|---|---|
| Baseline +5169 APKs have `+5169` in name | ✅ Confirmed (3/3 APKs) |
| Baseline signing fingerprint recorded | ✅ `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051` |
| New coordination commit SHA | ✅ `12ba24aa` |
| New commit count = +5170 | ✅ Confirmed via `git rev-list --count` |
| Product code unchanged from +5169 | ✅ Zero diff excluding `records/` |
| CI run 27868372344 conclusion | ✅ success (3/3 jobs) |
| Build run 27868385432 conclusion | ✅ success (Release Android passed) |
| New prerelease APKs have `+5170` in name | ✅ Confirmed (3/3 APKs) |
| New prerelease signing fingerprint matches baseline | ✅ Exact match |
| New prerelease is prerelease=true, draft=false | ✅ Confirmed |
| Smoke run 27868701836 conclusion | ✅ success (all steps passed) |

---

## Risk Assessment

- **Low risk**: All CI, build, prerelease, and smoke steps passed. Signing fingerprint is identical to baseline. Product code is unchanged except for records files.
- The new commit only adds monitoring records — no functional changes, no regression risk.
- APK digests differ from baseline as expected (version string `+5170` vs `+5169` causes bit-level difference).

---

## Unknowns

- The actual APK runtime behavior on a physical device was not verified (emulator-only smoke). This is acceptable for a records-only commit.
- The content of uploaded smoke evidence artifacts was not inspected; only job/step conclusions were checked.
- The `win_x64`, `ios`, `linux_x64`, `mac` build platforms were skipped — expected for Android-only APK release but worth noting.

---

## Changes or Recommendations

- **No changes recommended.** All verification gates passed.
- This is a records-only commit that adds monitoring documentation. The prerelease is correctly tagged, signed, and smoke-tested.

---

## Client Decision Needed?

**No.** All automated checks passed. The evidence is internally consistent:
- Same signing certificate across baseline and new prerelease
- Same product code (only records changed)
- CI + Build + Smoke all green

Codex may cite this report as evidence that the task066 +5169 GitHub-only prerelease pipeline completed successfully.

---

_This is candidate monitor output pending Codex review. Only Codex may decide whether evidence is citable or sufficient._
