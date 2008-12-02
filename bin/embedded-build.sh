#!/bin/sh

SDKS=""

TARGET="PlausibleDatabase-iPhoneOS"
LIBNAME="libpldatabase.a"
BUILD="build"
RELEASE="pldatabase-release-`date +%Y%m%d`"

print_usage () {
    echo "embedded-build.sh [-c <configuration>] [-s <sdk>] ..."
    echo "Options:"
    echo "-c:    Select the build configuration (Release or Debug)"
    echo "-s:    Specify the SDKs to build against (See xcodebuild -showsdks)."
    echo "       Multiple -s options may be supplied -- the results will be lipo'd together."
}

# This script is now deprecated. To maintain backwards compatibility, it will still generate
# a compatible "embedded" build by manually retargeting the iPhoneOS build target
# at the requested SDKs. This is fragile, and expected to break in the future, at which time
# this script will be retired.
echo "NOTE:"
echo "This release build mechanism has been deprecated in favor of ./bin/release-build.sh, and may be removed in future versions."
echo "Run ./bin/release-build.sh -h for more information. The release build script provides drop-in frameworks for all supported platforms."
echo "Do you wish to continue? (yes/no): \c"
read REPLY

case $REPLY in
    yes|YES|y)
        ;;
    *)
        exit 0;
        ;;
esac

# Read in the command line arguments
while getopts c:s: OPTION; do
    case ${OPTION} in
        c)
            CONFIGURATION="$OPTARG";;
        s)
            SDKS="$SDKS $OPTARG";;
        *)
            print_usage
            exit 1;;
    esac
done
shift $(($OPTIND - 1))

if [ -z "$CONFIGURATION" ]; then
    print_usage
    exit 1
fi

if [ -z "$SDKS" ]; then
    print_usage
    exit 1
fi

# Do the build
for sdk in $SDKS; do
    case $sdk in
        macosx*)
            xcodebuild -target $TARGET -sdk $sdk -configuration $CONFIGURATION ARCHS="i386 ppc"
            ;;
        *)
            xcodebuild -target $TARGET -sdk $sdk -configuration $CONFIGURATION
            ;;
    esac
done

# Create the release directory
mkdir $RELEASE

# Copy in the headers
cp Classes/*.h $RELEASE/

# Collate the builds into one archive file
for sdk in $SDKS; do
    SDK_NAME="${sdk%%[0-9]*.[0-9]*}"
    case $sdk in
        iphone*)
            LIBS="${LIBS} ${BUILD}/${CONFIGURATION}-${SDK_NAME}/libPlausibleDatabase-${SDK_NAME}.a"
        ;;
        macosx*)
            LIBS="${LIBS} ${BUILD}/${CONFIGURATION}/libPlausibleDatabase.a"
        ;;
    esac
done
lipo $LIBS -create -output "$RELEASE/$LIBNAME"
