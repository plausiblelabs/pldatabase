#!/bin/sh

SDKS=""

TARGET="pldatabase"
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
    xcodebuild -target $TARGET -sdk $sdk -configuration $CONFIGURATION
done

# Create the release directory
mkdir $RELEASE

# Copy in the headers
cp Classes/*.h $RELEASE/

# Collate the builds into one archive file
for sdk in $SDKS; do
    LIBS="${LIBS} ${BUILD}/${CONFIGURATION}-${sdk%%[0-9]*.[0-9]*}/${LIBNAME}"
done
lipo $LIBS -create -output "$RELEASE/$LIBNAME"
