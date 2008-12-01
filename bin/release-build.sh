#!/bin/sh

# Default configuration
CONFIGURATION="Release"

# Platforms to build
PLATFORMS="MacOSX iPhoneOS iPhoneSimulator Windows-i386"

# The primary platform, from which headers will be copied
PRIMARY_PLATFORM="MacOSX"

# Platforms that should be combined into a single iPhone output directory
# The iPhoneOS/iPhoneSimulator platforms are unique (and, arguably, broken) in this regard
IPHONE_PLATFORMS="iPhoneOS iPhoneSimulator"

# Base product name
PRODUCT="PlausibleDatabase"

VERSION=""

print_usage () {
    echo "`basename $0` <configuration> <version>"
}

CONFIGURATION=$1
VERSION=$2

if [ -z "$VERSION" ] || [ -z "${CONFIGURATION}" ]; then
    print_usage
    exit 1
fi

# Check for program failure
check_failure () {
    if [ $? != 0 ]; then
        echo "ERROR: $1"
        exit 1
    fi
}

# Build all platforms targets, and execute their unit tests.
for platform in ${PLATFORMS}; do
    xcodebuild -configuration $CONFIGURATION -target ${PRODUCT}-${platform}
    check_failure "Build for ${PRODUCT}-${platform} failed"

    # Check for unit tests, run them if available
    xcodebuild -list | grep -q Tests-${platform}
    if [ $? = 0 ]; then
        xcodebuild -configuration ${CONFIGURATION} -target Tests-${platform}
        check_failure "Unit tests for ${PRODUCT}-${platform} failed"
    fi
done

# Build the output directory
copy_build () {
    # Arguments
    local PLATFORM=$1
    local ROOT_OUTPUT_DIR=$2

    # Determine if this platform is an iPhone OS platform
    for phone_platform in ${IPHONE_PLATFORMS}; do
        if [ "${PLATFORM}" = "${phone_platform}" ]; then
            local IPHONE_PLATFORM=YES
        fi
    done


    # Input files/directories
    local PLATFORM_BUILD_DIR="build/${CONFIGURATION}-${platform}"
    local PLATFORM_FRAMEWORK="${PLATFORM_BUILD_DIR}/${PRODUCT}.framework"
    local CANONICAL_FRAMEWORK="build/${CONFIGURATION}-${PRIMARY_PLATFORM}/${PRODUCT}.framework"
    local PLATFORM_STATIC_LIB="${PLATFORM_BUILD_DIR}/lib${PRODUCT}.a"
    local PLATFORM_SPECIFIC_STATIC_LIB="${PLATFORM_BUILD_DIR}/lib${PRODUCT}-`echo ${PLATFORM} | tr '[A-Z]' '[a-z]'`.a"

    # Output files/directories
    local PLATFORM_OUTPUT_DIR="${ROOT_OUTPUT_DIR}/${PLATFORM}"

    # The iPhone-combined simulator/device is a special case. They're nearly identical APIs, and are intended to be used
    # in conjunction, retargeting a single target at either the Simulator or the Device. However, the simulator/device
    # implementations are not identical, and a project can not be built Universal. We handle that special case here,
    # by outputting a combined iPhone SDK release that includes specially named static libraries in a single
    # iPhone output directory
    if [ "${IPHONE_PLATFORM}" = "YES" ]; then
        # For the iPhone-combined simulator/device platforms, a platform-specific static library name is used
        local PLATFORM_STATIC_LIB="${PLATFORM_SPECIFIC_STATIC_LIB}"

        # A single combined 'iPhone' output directory is used.
        local PLATFORM_OUTPUT_DIR="${ROOT_OUTPUT_DIR}/iPhone"
    fi


    # Check if the platform was built
    if [ ! -d "${PLATFORM_BUILD_DIR}" ]; then
        echo "Missing build results for ${PLATFORM_BUILD_DIR}"
        exit 1
    fi

    # Create the output directory if it does not exist
    mkdir -p "${PLATFORM_OUTPUT_DIR}"
    check_failure "Could not create directory: ${PLATFORM_OUTPUT_DIR}"

    # Copy in a framework build, if it exists
    if [ -d "${PLATFORM_FRAMEWORK}" ]; then
        echo "${PLATFORM}: Copying ${PLATFORM_FRAMEWORK}"
        tar -C `dirname "${PLATFORM_FRAMEWORK}"` -cf - "${PRODUCT}.framework" | tar -C "${PLATFORM_OUTPUT_DIR}" -xf -
        check_failure "Could not copy framework ${PLATFORM_FRAMEWORK}"
    fi

    # Copy in a static lib build, if it exists
    if [ -f "${PLATFORM_STATIC_LIB}" ]; then
        mkdir -p "${PLATFORM_OUTPUT_DIR}/lib"
        check_failure "Could not create output directory"

        mkdir -p "${PLATFORM_OUTPUT_DIR}/include/${PRODUCT}"
        check_failure "Could not create output directory"

        echo "${PLATFORM}: Copying ${PLATFORM_STATIC_LIB}"
        cp -p "${PLATFORM_STATIC_LIB}" "${PLATFORM_OUTPUT_DIR}/lib"
        check_failure "Could not copy static lib ${PLATFORM_STATIC_LIB}"

        echo "${PLATFORM}: Copying header files from canonical framework"
        cp -Rp "${CANONICAL_FRAMEWORK}/Headers/"* "${PLATFORM_OUTPUT_DIR}/include/${PRODUCT}"
        check_failure "Could not copy headers from ${CANONICAL_FRAMEWORK}"
    fi
}

# Copy the platform build results
OUTPUT_DIR="${PRODUCT}-${VERSION}"
if [ -d "${OUTPUT_DIR}" ]; then
    echo "Output directory ${OUTPUT_DIR} already exists"
    exit 1
fi
mkdir -p "${OUTPUT_DIR}"

for platform in ${PLATFORMS}; do
    echo "Copying ${platform} build to ${OUTPUT_DIR}"
    copy_build ${platform} "${OUTPUT_DIR}"
done

# Build the documentation
doxygen
check_failure "Documentation generation failed"

mv docs "${OUTPUT_DIR}/Documentation"
check_failure "Documentation generation failed"

# Copy in the README file (TODO)
#

# Build the DMG
hdiutil create -srcfolder "${OUTPUT_DIR}" "${OUTPUT_DIR}.dmg"
check_failure "DMG generation failed"
