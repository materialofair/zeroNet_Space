#!/bin/sh

set -eu

project_root="${SRCROOT:?SRCROOT is required}"
archive_path="${ARCHIVE_PATH:?ARCHIVE_PATH is required}"
cd "$project_root"

current_build_number="$(xcrun agvtool what-version -terse | tail -n 1)"
archive_info_plist="$archive_path/Info.plist"

case "$current_build_number" in
    ''|*[!0-9]*)
        echo "error: CURRENT_PROJECT_VERSION must be an integer, got '$current_build_number'."
        exit 1
        ;;
esac

if [ ! -f "$archive_info_plist" ]; then
    echo "error: Archive Info.plist not found at '$archive_info_plist'. Build number was not changed."
    exit 1
fi

# PostAction 即使归档失败也会执行；失败归档的 Products 目录下没有完整 .app 包，
# 以 .app 存在作为归档成功的前置条件，防止失败归档后构建号被错误递增。
archived_app_bundle="$(
    find "$archive_path/Products/Applications" -maxdepth 1 -name '*.app' -type d 2>/dev/null \
        | head -n 1
)"
if [ -z "$archived_app_bundle" ]; then
    echo "error: No .app bundle found in archive. The archive may have failed; build number was not changed."
    exit 1
fi

archived_build_number="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :ApplicationProperties:CFBundleVersion' \
        "$archive_info_plist"
)"

if [ "$archived_build_number" != "$current_build_number" ]; then
    echo "error: Archive contains build $archived_build_number, but the project is $current_build_number. Build number was not changed."
    exit 1
fi

xcrun agvtool next-version -all

next_build_number="$(xcrun agvtool what-version -terse | tail -n 1)"
expected_build_number="$((current_build_number + 1))"

if [ "$next_build_number" -ne "$expected_build_number" ]; then
    echo "error: Expected build number $expected_build_number, got $next_build_number."
    exit 1
fi

echo "Archived build $archived_build_number successfully. Next build number: $next_build_number"
