#!/bin/sh

# Default configuration
CONFIGURATION="Release"

# Platforms to build
PLATFORMS="MacOSX Windows-i386"

# Platforms that should be combined into a single iPhone output directory
# The iPhoneOS/iPhoneSimulator platforms are unique (and, arguably, broken) in this regard
IPHONE_PLATFORMS="iPhoneOS iPhoneSimulator"

# The primary platform, from which headers will be copied
PRIMARY_PLATFORM="MacOSX"

# Base product name
PRODUCT="PlausibleDatabase"

VERSION=""

# List of all iPhone static libs. Populated by copy_build()
IPHONE_PRODUCT_LIBS=""

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
    local PLATFORM_SDK_NAME=`echo ${PLATFORM} | tr '[A-Z]' '[a-z]'`
    local PLATFORM_SPECIFIC_STATIC_LIB="${PLATFORM_BUILD_DIR}/lib${PRODUCT}-${PLATFORM_SDK_NAME}.a"

    # Output files/directories
    local PLATFORM_OUTPUT_DIR="${ROOT_OUTPUT_DIR}/${PRODUCT}-${PLATFORM}"

    # For the iPhone-combined simulator/device platforms, a platform-specific static library name is used
    if [ "${IPHONE_PLATFORM}" = "YES" ]; then
        local PLATFORM_STATIC_LIB="${PLATFORM_SPECIFIC_STATIC_LIB}"
        IPHONE_STATIC_LIBS="${IPHONE_STATIC_LIBS} ${PLATFORM_STATIC_LIB}"
    fi


    # Check if the platform was built
    if [ ! -d "${PLATFORM_BUILD_DIR}" ]; then
        echo "Missing build results for ${PLATFORM_BUILD_DIR}"
        exit 1
    fi

    if [ ! -d "${PLATFORM_FRAMEWORK}" ]; then
        echo "Missing framework build for ${PLATFORM_BUILD_DIR}"
        exit 1
    fi

    # Create the output directory if it does not exist
    mkdir -p "${PLATFORM_OUTPUT_DIR}"
    check_failure "Could not create directory: ${PLATFORM_OUTPUT_DIR}"

    # Copy in built framework
    echo "${PLATFORM}: Copying ${PLATFORM_FRAMEWORK}"
    tar -C `dirname "${PLATFORM_FRAMEWORK}"` -cf - "${PRODUCT}.framework" | tar -C "${PLATFORM_OUTPUT_DIR}" -xf -
    check_failure "Could not copy framework ${PLATFORM_FRAMEWORK}"

    # Copy in static lib, if it exists
    if [ -f "${PLATFORM_STATIC_LIB}" ]; then
        cp "${PLATFORM_STATIC_LIB}" "${PLATFORM_OUTPUT_DIR}"
    fi 
}

# Copy the platform build results
OUTPUT_DIR="${PRODUCT}-${VERSION}"
if [ -d "${OUTPUT_DIR}" ]; then
    echo "Output directory ${OUTPUT_DIR} already exists"
    exit 1
fi
mkdir -p "${OUTPUT_DIR}"

# Standard builds
for platform in ${PLATFORMS}; do
    echo "Copying ${platform} build to ${OUTPUT_DIR}"
    copy_build ${platform} "${OUTPUT_DIR}"
done

# Output the iPhone builds
for platform in ${IPHONE_PLATFORMS}; do
    copy_build ${platform} "${OUTPUT_DIR}/${PRODUCT}-iPhone/"
done

# Build a single iPhoneOS/iPhoneSimulator static framework
for platform in ${IPHONE_PLATFORMS}; do
    tar -C "${OUTPUT_DIR}/${PRODUCT}-iPhone/${PRODUCT}-${platform}" -cf - "${PRODUCT}.framework" | tar -C "${OUTPUT_DIR}/${PRODUCT}-iPhone/" -xf -
    check_failure "Could not copy framework ${platform} framework"

    rm -r "${OUTPUT_DIR}/${PRODUCT}-iPhone/${PRODUCT}-${platform}"
    check_failure "Could not delete framework ${platform} framework"
done

lipo $IPHONE_STATIC_LIBS -create -output "${OUTPUT_DIR}/${PRODUCT}-iPhone/${PRODUCT}.framework/Versions/Current/${PRODUCT}"
check_failure "Could not lipo iPhone framework"

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
