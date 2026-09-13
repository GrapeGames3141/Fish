#!/usr/bin/env bash
# Export the Hooked Play release AAB (and optionally a debug APK).
# Run from repo root on Ubuntu CI or locally.
# Set SKIP_DEBUG_APK=1 to export only the Play AAB.
set -euo pipefail

# BASH_SOURCE, not $0: the CI test step sources this file to reuse install_godot.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT"
GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_TAG="${GODOT_VERSION}-${GODOT_CHANNEL}"
GODOT_SHARE_DIR="${GODOT_SHARE_DIR:-$HOME/.local/share/godot}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hooked}"

EXPORT_PRESET="${EXPORT_PRESET:-Android Play}"
RELEASE_PACKAGE_NAME="${RELEASE_PACKAGE_NAME:-com.grapegames.hooked}"
DEBUG_PACKAGE_NAME="${DEBUG_PACKAGE_NAME:-com.tak.castandcrank}"
ARTIFACT_STEM="${ARTIFACT_STEM:-Hooked}"
# Google's official sample AdMob app ID. Closed testing serves test ads only;
# see docs/PLAY_ANDROID.md before switching to the production app ID.
ADMOB_ANDROID_APP_ID="${ADMOB_ANDROID_APP_ID:-ca-app-pub-3940256099942544~3347511713}"
VERSION_CODE="${VERSION_CODE:-1}"
VERSION_NAME="${VERSION_NAME:-1.${VERSION_CODE}}"

PRESET_PATH=""
PRESET_BACKUP=""
PROJECT_SETTINGS_PATH=""
PROJECT_SETTINGS_BACKUP=""
BUILD_TEMPLATE_BACKUP=""
# android/build is tracked source here, but Godot rewrites these during every
# export (each carries its own "overwritten at build time" banner), and the Play
# overlay edits build.gradle. Snapshot them so a run leaves no diff.
TRACKED_BUILD_PATHS=(
	"build.gradle"
	"gradle.properties"
	"gradlew"
	".gdignore"
	"src/main/AndroidManifest.xml"
	"src/instrumented/AndroidManifest.xml"
	"res/values/themes.xml"
)

restore_export_files() {
	restore_tracked_build_template
	if [[ -n "$PRESET_BACKUP" && -f "$PRESET_BACKUP" && -n "$PRESET_PATH" ]]; then
		cp "$PRESET_BACKUP" "$PRESET_PATH"
		rm -f "$PRESET_BACKUP"
	fi
	if [[ -n "$PROJECT_SETTINGS_BACKUP" && -f "$PROJECT_SETTINGS_BACKUP" && -n "$PROJECT_SETTINGS_PATH" ]]; then
		cp "$PROJECT_SETTINGS_BACKUP" "$PROJECT_SETTINGS_PATH"
		rm -f "$PROJECT_SETTINGS_BACKUP"
	fi
}

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "${ANDROID_SDK_ROOT}" ]]; then
	echo "ANDROID_SDK_ROOT or ANDROID_HOME must be set" >&2
	exit 1
fi
# A mismatch between the two variables is the documented cause of a Gradle export
# that dies before an artifact exists; pin both to the same SDK.
export ANDROID_HOME="$ANDROID_SDK_ROOT"

configure_godot_android_paths() {
	local settings_dir="$HOME/.config/godot"
	mkdir -p "$settings_dir"
	local settings_file="$settings_dir/editor_settings-4.tres"
	local java_home="${JAVA_HOME:-}"
	if [[ -z "$java_home" ]] && command -v java >/dev/null 2>&1; then
		java_home="$(readlink -f "$(command -v java)" | sed 's|/bin/java||')"
	fi
	cat >"$settings_file" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_SDK_ROOT}"
export/android/java_sdk_path = "${java_home}"
EOF
}

start_adb_server() {
	local adb_bin="${ANDROID_SDK_ROOT}/platform-tools/adb"
	if [[ -x "$adb_bin" ]]; then
		"$adb_bin" start-server >/dev/null 2>&1 || true
	elif command -v adb >/dev/null 2>&1; then
		adb start-server >/dev/null 2>&1 || true
	fi
}

install_godot() {
	local cache="$CACHE_ROOT/godot"
	mkdir -p "$cache" "$HOME/.local/bin"
	local zip="Godot_v${GODOT_TAG}_linux.x86_64.zip"
	if ! command -v godot >/dev/null 2>&1; then
		if [[ ! -f "$cache/$zip" ]]; then
			curl -fsSL -o "$cache/$zip" \
				"https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}/${zip}"
		fi
		unzip -qo "$cache/$zip" -d "$cache"
		install -m 755 "$cache/Godot_v${GODOT_TAG}_linux.x86_64" "$HOME/.local/bin/godot"
	fi
	install_godot_export_templates
}

expected_android_build_version() {
	printf '%s.%s\n' "$GODOT_VERSION" "$GODOT_CHANNEL"
}

android_export_template_dir() {
	local marker="$PROJECT/android/.build_version"
	local expected actual
	expected="$(expected_android_build_version)"
	if [[ -f "$marker" ]]; then
		actual="$(tr -d '\r\n' <"$marker")"
		if [[ "$actual" != "$expected" ]]; then
			echo "ERROR: android/.build_version is '${actual}'; CI uses Godot ${expected}" >&2
			exit 1
		fi
		printf '%s\n' "$actual"
		return 0
	fi
	printf '%s\n' "$expected"
}

install_godot_export_templates() {
	local cache="$CACHE_ROOT/godot"
	local tpz="Godot_v${GODOT_TAG}_export_templates.tpz"
	local template_dir
	template_dir="$(android_export_template_dir)"
	local template_root="$GODOT_SHARE_DIR/export_templates/${template_dir}"
	if [[ -s "$template_root/android_source.zip" ]]; then
		return 0
	fi
	mkdir -p "$cache"
	if [[ ! -f "$cache/$tpz" ]]; then
		curl -fsSL -o "$cache/$tpz" \
			"https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}/${tpz}"
	fi
	mkdir -p "$template_root"
	unzip -qo "$cache/$tpz" -d "$cache/templates_unpack"
	cp -a "$cache/templates_unpack/templates/." "$template_root/"
	[[ -s "$template_root/android_source.zip" ]] || {
		echo "ERROR: export templates missing android_source.zip under ${template_root}" >&2
		exit 1
	}
}

sanitize_android_build_template() {
	local build_dir="$PROJECT/android/build"
	[[ -f "$build_dir/.gdignore" ]] || : >"$build_dir/.gdignore"
	find "$build_dir" -type f -name '*.import' -delete
}

restore_tracked_build_template() {
	local build_dir="$PROJECT/android/build"
	if [[ -n "$BUILD_TEMPLATE_BACKUP" && -f "$BUILD_TEMPLATE_BACKUP/template.tar" ]]; then
		tar -xf "$BUILD_TEMPLATE_BACKUP/template.tar" -C "$build_dir"
	fi
	if [[ -n "$BUILD_TEMPLATE_BACKUP" && -d "$BUILD_TEMPLATE_BACKUP" ]]; then
		rm -rf "$BUILD_TEMPLATE_BACKUP"
		BUILD_TEMPLATE_BACKUP=""
	fi
}

backup_tracked_build_template() {
	local build_dir="$PROJECT/android/build"
	BUILD_TEMPLATE_BACKUP="$(mktemp -d)"
	local -a present=()
	local path
	for path in "${TRACKED_BUILD_PATHS[@]}"; do
		[[ -e "$build_dir/$path" ]] && present+=("$path")
	done
	# Every locale's app-name string is rewritten with the project name.
	while IFS= read -r path; do
		present+=("${path#"$build_dir/"}")
	done < <(find "$build_dir/res" -name 'godot_project_name_string.xml' 2>/dev/null)
	if [[ "${#present[@]}" -gt 0 ]]; then
		# tar preserves the executable bit on gradlew, which a plain copy loses.
		tar -cf "$BUILD_TEMPLATE_BACKUP/template.tar" -C "$build_dir" "${present[@]}"
	fi
}

ensure_android_build_template() {
	local build_dir="$PROJECT/android/build"
	local marker="$build_dir/build.gradle"
	local godot_aar template_dir android_source expected_version
	expected_version="$(android_export_template_dir)"

	# The template source is committed; only the Godot engine AAR under libs/ is
	# generated (and gitignored), so a fresh checkout needs just that restored.
	if [[ ! -f "$marker" ]]; then
		install_godot_export_templates
		template_dir="$(android_export_template_dir)"
		android_source="$GODOT_SHARE_DIR/export_templates/${template_dir}/android_source.zip"
		[[ -s "$android_source" ]] || {
			echo "ERROR: missing Android source template at $android_source" >&2
			exit 1
		}
		echo "android/build is absent; installing the template from ${android_source}..."
		mkdir -p "$build_dir"
		unzip -qo "$android_source" -d "$build_dir"
	fi

	godot_aar="$(find "$build_dir/libs" -name 'godot-lib*.aar' -type f 2>/dev/null | head -1 || true)"
	if [[ -z "$godot_aar" || ! -s "$godot_aar" ]]; then
		install_godot_export_templates
		template_dir="$(android_export_template_dir)"
		android_source="$GODOT_SHARE_DIR/export_templates/${template_dir}/android_source.zip"
		echo "Restoring generated engine libraries from ${android_source}..."
		# Only libs/: everything else in android/build is tracked and must not be
		# overwritten by a template extract.
		unzip -qo "$android_source" 'libs/*' -d "$build_dir"
		godot_aar="$(find "$build_dir/libs" -name 'godot-lib*.aar' -type f 2>/dev/null | head -1 || true)"
	fi

	[[ -x "$build_dir/gradlew" ]] || chmod +x "$build_dir/gradlew"
	printf '%s\n' "$expected_version" >"$build_dir/.build_version"
	sanitize_android_build_template

	[[ -f "$marker" && -n "$godot_aar" && -s "$godot_aar" ]] || {
		echo "ERROR: android/build lacks build.gradle or godot-lib*.aar" >&2
		exit 1
	}
	echo "Android build template ready ($(du -sh "$build_dir" | cut -f1))"
}

require_admob_android_binaries() {
	local bin_dir="$PROJECT/addons/admob/android/bin"
	local marker="$bin_dir/ads/libs/poing-godot-admob-ads-release.aar"
	# Poing AdMob v5.0.0 binaries are tracked in this repo; a release export
	# without them would ship a silently ad-free build.
	if [[ ! -s "$marker" || ! -f "$bin_dir/package.gd" ]]; then
		echo "ERROR: AdMob Android binaries missing (expected $marker)" >&2
		exit 1
	fi
	echo "AdMob Android binaries present ($(du -sh "$bin_dir" | cut -f1))"
}

set_project_android_app_id() {
	local app_id="$1"
	local settings="${2:-$PROJECT/project.godot}"
	awk -v id="$app_id" '
		BEGIN { in_admob=0; found_section=0; found_id=0 }
		/^\[admob\]$/ {
			in_admob=1
			found_section=1
			print
			next
		}
		/^\[/ {
			if (in_admob && !found_id) {
				print "general/android/app_id=\"" id "\""
				found_id=1
			}
			in_admob=0
		}
		/^general\/android\/app_id=/ {
			if (in_admob) {
				print "general/android/app_id=\"" id "\""
				found_id=1
				next
			}
		}
		{ print }
		END {
			if (in_admob && !found_id) {
				print "general/android/app_id=\"" id "\""
				found_id=1
			}
			if (!found_section) {
				print ""
				print "[admob]"
				print ""
				print "general/android/app_id=\"" id "\""
			}
		}
	' "$settings" >"${settings}.tmp"
	mv "${settings}.tmp" "$settings"
	echo "AdMob Android app ID set to ${app_id}"
}

# Mutate one named Android export preset block in export_presets.cfg.
with_preset() {
	local preset_name="$1"
	local awk_body="$2"
	local preset="$PROJECT/export_presets.cfg"
	awk -v want="$preset_name" "$awk_body" "$preset" >"${preset}.tmp"
	mv "${preset}.tmp" "$preset"
}

bump_version() {
	with_preset "$EXPORT_PRESET" '
		BEGIN { in_play=0 }
		/^name="/ {
			in_play = ($0 == "name=\"" want "\"")
		}
		in_play && /^version\/code=/ { print "version/code=" ENVIRON["VERSION_CODE"]; next }
		in_play && /^version\/name=/ { print "version/name=\"" ENVIRON["VERSION_NAME"] "\""; next }
		{ print }
	'
	echo "Android ($EXPORT_PRESET) versionCode=${VERSION_CODE} versionName=${VERSION_NAME}"
}

patch_android_soft_input() {
	local build_dir="$PROJECT/android/build"
	local patched=0
	while IFS= read -r -d '' manifest; do
		if grep -q 'android:windowSoftInputMode=' "$manifest"; then
			sed -i 's/android:windowSoftInputMode="[^"]*"/android:windowSoftInputMode="adjustNothing"/g' "$manifest"
		elif grep -q '<activity' "$manifest"; then
			sed -i 's/<activity /<activity android:windowSoftInputMode="adjustNothing" /' "$manifest"
		else
			continue
		fi
		patched=1
		echo "Pinned Android soft-input mode to adjustNothing in ${manifest#"$PROJECT/"}"
	done < <(find "$build_dir" -name AndroidManifest.xml -print0)
	if [[ "$patched" -eq 0 ]]; then
		echo "WARNING: no AndroidManifest.xml found to pin windowSoftInputMode" >&2
	fi
}

patch_android_play_gradle() {
	local build_dir="$PROJECT/android/build"
	local app_gradle="$build_dir/build.gradle"
	local overlay="$PROJECT/android/play-release.gradle"
	local rules="$PROJECT/android/proguard-godot-play.pro"
	[[ -f "$app_gradle" ]] || { echo "ERROR: Godot Android gradle project missing at $app_gradle" >&2; exit 1; }
	[[ -f "$overlay" && -f "$rules" ]] || { echo "ERROR: Play gradle overlay files missing under android/" >&2; exit 1; }
	cp "$rules" "$build_dir/proguard-godot-play.pro"
	cp "$overlay" "$build_dir/play-release.gradle"
	patch_android_soft_input
	if grep -q "play-release.gradle" "$app_gradle"; then
		echo "Play R8 overlay already applied to android/build"
		return 0
	fi
	{
		echo ""
		echo "// Grapegames Play overlay: R8 shrinking + uncompressed native libs for 16 KB pages"
		echo 'apply from: "play-release.gradle"'
	} >> "$app_gradle"
	if [[ -f "$build_dir/gradle.properties" ]]; then
		if ! grep -q "android.bundle.enableUncompressedNativeLibs" "$build_dir/gradle.properties"; then
			printf '\nandroid.bundle.enableUncompressedNativeLibs=true\n' >> "$build_dir/gradle.properties"
		fi
	fi
	echo "Applied Play R8 / 16 KB packaging overlay to android/build"
}

set_package_name() {
	local package_name="$1"
	PACKAGE_NAME="$package_name" with_preset "$EXPORT_PRESET" '
		BEGIN { in_play=0 }
		/^name="/ {
			in_play = ($0 == "name=\"" want "\"")
		}
		in_play && /^package\/unique_name=/ {
			print "package/unique_name=\"" ENVIRON["PACKAGE_NAME"] "\""
			next
		}
		{ print }
	'
}

set_export_format() {
	local format="$1"
	EXPORT_FORMAT="$format" with_preset "$EXPORT_PRESET" '
		BEGIN { in_play=0 }
		/^name="/ {
			in_play = ($0 == "name=\"" want "\"")
		}
		in_play && /^gradle_build\/export_format=/ {
			print "gradle_build/export_format=" ENVIRON["EXPORT_FORMAT"]
			next
		}
		{ print }
	'
}

standalone_bundletool() {
	local version="${BUNDLETOOL_VERSION:-1.16.0}"
	local cache_dir="${BUNDLETOOL_CACHE_DIR:-$CACHE_ROOT/bundletool}"
	local jar="${BUNDLETOOL_JAR:-$cache_dir/bundletool-all-${version}.jar}"
	if [[ ! -s "$jar" ]]; then
		mkdir -p "$cache_dir"
		# Progress goes to stderr; stdout is captured by the caller as the jar path.
		echo "Downloading official Bundletool ${version} for AAB validation..." >&2
		curl -fsSL -o "$jar" "https://github.com/google/bundletool/releases/download/${version}/bundletool-all-${version}.jar"
	fi
	[[ -s "$jar" ]] || { echo "ERROR: standalone Bundletool download is empty" >&2; exit 1; }
	java -jar "$jar" version >/dev/null || { echo "ERROR: standalone Bundletool is not executable" >&2; exit 1; }
	echo "$jar"
}

expect_manifest_value() {
	local label="$1" actual="$2" expected="$3"
	if [[ "$actual" != "$expected" ]]; then
		echo "ERROR: ${label} mismatch (expected '${expected}', got '${actual}')" >&2
		exit 1
	fi
}

validate_artifact() {
	local artifact="$1" package_name="$2" expected_code="$3" expected_name="$4"
	[[ -s "$artifact" ]] || { echo "ERROR: missing Android artifact $artifact" >&2; exit 1; }
	if [[ "$artifact" == *.apk ]]; then
		local apkanalyzer="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/apkanalyzer"
		[[ -x "$apkanalyzer" ]] || apkanalyzer="$(find "${ANDROID_SDK_ROOT}/cmdline-tools" -name apkanalyzer -type f | head -1)"
		[[ -x "$apkanalyzer" ]] || { echo "ERROR: apkanalyzer is required for APK metadata validation" >&2; exit 1; }
		expect_manifest_value "APK package" "$("$apkanalyzer" manifest application-id "$artifact")" "$package_name"
		expect_manifest_value "APK versionCode" "$("$apkanalyzer" manifest version-code "$artifact")" "$expected_code"
		expect_manifest_value "APK versionName" "$("$apkanalyzer" manifest version-name "$artifact")" "$expected_name"
	else
		local bundletool
		bundletool="$(standalone_bundletool)"
		expect_manifest_value "AAB package" \
			"$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@package)" \
			"$package_name"
		expect_manifest_value "AAB versionCode" \
			"$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@android:versionCode)" \
			"$expected_code"
		expect_manifest_value "AAB versionName" \
			"$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@android:versionName)" \
			"$expected_name"
	fi
}

ensure_project_imported() {
	echo "Importing project assets..."
	# Always run --import: it is incremental and repairs partial CI cache restores
	# where .godot/imported exists but preloads still fail to load.
	godot --headless --path "$PROJECT" --import
	if ! godot --headless --path "$PROJECT" --quit; then
		echo "ERROR: Project failed to load after import (check committed .import sidecars and generated assets)" >&2
		exit 1
	fi
}

export_android() {
	mkdir -p "$PROJECT/builds/android"
	export VERSION_CODE VERSION_NAME
	PRESET_PATH="$PROJECT/export_presets.cfg"
	PRESET_BACKUP="$(mktemp)"
	cp "$PRESET_PATH" "$PRESET_BACKUP"
	PROJECT_SETTINGS_PATH="$PROJECT/project.godot"
	PROJECT_SETTINGS_BACKUP="$(mktemp)"
	cp "$PROJECT_SETTINGS_PATH" "$PROJECT_SETTINGS_BACKUP"
	trap restore_export_files EXIT
	require_admob_android_binaries
	set_project_android_app_id "$ADMOB_ANDROID_APP_ID"
	bump_version
	configure_godot_android_paths
	start_adb_server

	ensure_project_imported

	local aab_path="$PROJECT/builds/android/${ARTIFACT_STEM}.aab"
	local apk_path="$PROJECT/builds/android/${ARTIFACT_STEM}-debug.apk"

	echo "Installing Godot Android gradle template..."
	# Snapshot before the template step, which chmods gradlew: the tar must hold
	# the committed mode, not the one the export needs.
	backup_tracked_build_template
	ensure_android_build_template
	patch_android_play_gradle

	echo "Exporting Play release AAB as ${RELEASE_PACKAGE_NAME}..."
	set_package_name "$RELEASE_PACKAGE_NAME"
	set_export_format 1
	godot --headless --path "$PROJECT" --verbose \
		--export-release "$EXPORT_PRESET" "$aab_path"
	validate_artifact "$aab_path" "$RELEASE_PACKAGE_NAME" "$VERSION_CODE" "$VERSION_NAME"

	if [[ "${SKIP_DEBUG_APK:-0}" == "1" ]]; then
		echo "Skipping debug APK export (SKIP_DEBUG_APK=1)."
	else
		echo "Exporting installable debug APK as ${DEBUG_PACKAGE_NAME}..."
		set_package_name "$DEBUG_PACKAGE_NAME"
		set_export_format 0
		godot --headless --path "$PROJECT" --verbose \
			--export-debug "$EXPORT_PRESET" "$apk_path"
		validate_artifact "$apk_path" "$DEBUG_PACKAGE_NAME" "$VERSION_CODE" "$VERSION_NAME"
		set_export_format 1
	fi
	restore_export_files
	trap - EXIT
}

main() {
	install_godot
	export_android
	echo "Done: $PROJECT/builds/android/${ARTIFACT_STEM}.aab"
	if [[ "${SKIP_DEBUG_APK:-0}" != "1" ]]; then
		echo "Done: $PROJECT/builds/android/${ARTIFACT_STEM}-debug.apk"
	fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main
fi
