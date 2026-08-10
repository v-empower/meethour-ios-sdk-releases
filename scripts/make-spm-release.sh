#!/bin/bash
#
# Packages the xcframeworks in Frameworks/ as Swift Package Manager artifacts.
#
# Produces one <name>.xcframework.zip per framework under spm-artifacts/, then
# rewrites Package.swift with the release version and each artifact's checksum.
# Upload the zips as assets on the GitHub Release whose tag equals the version;
# Package.swift points at
#   .../releases/download/<version>/<name>.xcframework.zip
#
# Usage:
#   ./scripts/make-spm-release.sh            # version from MeetHourSDK.podspec
#   ./scripts/make-spm-release.sh 5.0.18     # explicit version
#
set -e -u

THIS_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RELEASE_REPO=$(cd -P "${THIS_DIR}/.." && pwd)
OUT_DIR="${RELEASE_REPO}/spm-artifacts"

cd "${RELEASE_REPO}"

if [[ $# -ge 1 ]]; then
    VERSION="$1"
else
    # Same source of truth as the podspec, so the two package managers can never
    # drift onto different binaries.
    VERSION=$(sed -n "s/.*s\.version *= *'\([^']*\)'.*/\1/p" MeetHourSDK.podspec | head -1)
fi

if [[ -z "${VERSION}" ]]; then
    echo "ERROR: could not determine version. Pass it explicitly." >&2
    exit 1
fi

# <artifact name>:<path under Frameworks/>. Every wrapper name now matches its
# path, but the mapping is kept so a future artifact can be zipped under a name
# that differs from its directory - SPM insists the .xcframework inside a binary
# target's zip be named after the target.
FRAMEWORKS=(
    "MeetHourSDK:MeetHourSDK.xcframework"
    "MeetHourSDKModules:MeetHourSDKModules.xcframework"
    "WebRTC:WebRTC.xcframework"
    "hermesvm:hermesvm.xcframework"
    "React:React.xcframework"
    "ReactNativeDependencies:ReactNativeDependencies.xcframework"
)

echo "Packaging Meet Hour SDK ${VERSION} for Swift Package Manager"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

# Zip each xcframework and record its checksum. `swift package compute-checksum`
# is the only checksum SPM accepts -- a plain shasum will not match.
declare -a CHECKSUM_LINES=()
for entry in "${FRAMEWORKS[@]}"; do
    name="${entry%%:*}"
    src="Frameworks/${entry#*:}"
    if [[ ! -d "${src}" ]]; then
        echo "ERROR: ${src} not found. Run ios/scripts/release-sdk.sh first." >&2
        exit 1
    fi

    zip_path="${OUT_DIR}/${name}.xcframework.zip"
    echo "  zipping ${src} as ${name}.xcframework"

    # zip names entries after the directory on disk, so anything whose wrapper
    # name or location does not already match gets staged first. -c clones on
    # APFS, which makes this near-free for a ~1 GB framework.
    stage_dir=""
    if [[ "${src}" != "Frameworks/${name}.xcframework" ]]; then
        stage_dir=$(mktemp -d)
        cp -Rc "${src}" "${stage_dir}/${name}.xcframework" 2>/dev/null \
            || cp -R "${src}" "${stage_dir}/${name}.xcframework"
        zip_root="${stage_dir}"
    else
        zip_root="Frameworks"
    fi

    # -y keeps symlinks as symlinks: framework bundles rely on them, and
    # following them corrupts the copy SPM extracts.
    (cd "${zip_root}" && zip -q -r -y "${zip_path}" "${name}.xcframework")
    if [[ -n "${stage_dir}" ]]; then
        rm -rf "${stage_dir}"
    fi

    checksum=$(swift package compute-checksum "${zip_path}")

    # An empty or malformed checksum still produces a Package.swift that parses
    # and dumps cleanly, so it would sail past validation and only fail for
    # consumers at resolve time. Check the shape here instead.
    if [[ ! "${checksum}" =~ ^[0-9a-f]{64}$ ]]; then
        echo "ERROR: checksum for ${name} is not 64 hex characters: '${checksum}'" >&2
        exit 1
    fi

    echo "    ${checksum}"
    CHECKSUM_LINES+=("${name}=${checksum}")
done

# Rewrite Package.swift in place: version first, then each checksum.
echo "Updating Package.swift"
/usr/bin/sed -i '' -e "s/^let sdkVersion = \".*\"$/let sdkVersion = \"${VERSION}\"/" Package.swift

for entry in "${CHECKSUM_LINES[@]}"; do
    name="${entry%%=*}"
    checksum="${entry#*=}"
    /usr/bin/sed -i '' -e "s|\"${name}\": \"[^\"]*\"|\"${name}\": \"${checksum}\"|" Package.swift
done

# Keep the version string the shim targets report in step with the manifest.
/usr/bin/sed -i '' -e "s/public static let version = \".*\"/public static let version = \"${VERSION}\"/" \
    Sources/MeetHourSDK-Native/MeetHourSDK-Native.swift \
    Sources/MeetHourSDK-ReactNative/MeetHourSDK-ReactNative.swift

# A manifest that does not parse is worse than no manifest: fail the packaging
# run rather than tagging a release nobody can resolve.
echo "Validating Package.swift"
swift package dump-package > /dev/null

# Every checksum must have actually been substituted. A sed pattern that stops
# matching (say Package.swift gets reformatted) would otherwise leave the
# previous release's checksums in place, and SPM would either fetch the wrong
# binaries or fail verification against this tag.
if grep -q "REPLACE_WITH_CHECKSUM" Package.swift; then
    echo "ERROR: Package.swift still contains checksum placeholders:" >&2
    grep -n "REPLACE_WITH_CHECKSUM" Package.swift >&2
    exit 1
fi

for entry in "${CHECKSUM_LINES[@]}"; do
    name="${entry%%=*}"
    checksum="${entry#*=}"
    if ! grep -q "\"${name}\": \"${checksum}\"" Package.swift; then
        echo "ERROR: Package.swift does not carry the checksum just computed for ${name}." >&2
        echo "       Expected ${checksum}" >&2
        exit 1
    fi
done

if ! grep -q "^let sdkVersion = \"${VERSION}\"$" Package.swift; then
    echo "ERROR: Package.swift sdkVersion was not updated to ${VERSION}." >&2
    exit 1
fi

echo "OK: Package.swift parses, version is ${VERSION}, all ${#CHECKSUM_LINES[@]} checksums substituted"

echo
echo "Artifacts in ${OUT_DIR}:"
ls -lh "${OUT_DIR}" | tail -n +2 | awk '{print "  " $9 "  " $5}'
echo
echo "Next:"
echo "  1. Commit Package.swift and Sources/ (do NOT commit spm-artifacts/)."
echo "  2. git tag ${VERSION} && git push origin ${VERSION}"
echo "  3. gh release create ${VERSION} ${OUT_DIR}/*.zip --title ${VERSION}"
echo "     (or attach the zips to the release in the GitHub UI)"
echo "  4. Verify: swift package resolve in a scratch package depending on"
echo "     https://github.com/v-empower/meethour-ios-sdk-releases from ${VERSION}"
