DEVELOPER?=	$(shell xcode-select -print-path)
PLATFORMS?=	$(DEVELOPER)/Platforms/
CFLAGS?=	-Os -std=c99 \
		-DSQLITE_ENABLE_UNLOCK_NOTIFY

DEVICE_SDK?=		iPhoneOS5.1
DEVICE_PLATFORM?=	$(PLATFORMS)/iPhoneOS.platform
DEVICE_ROOT?=		$(DEVICE_PLATFORM)/Developer/SDKs/$(DEVICE_SDK).sdk
DEVICE_GCC?=		$(shell xcrun -sdk `echo ${DEVICE_SDK} | tr [A-Z] [a-z]` -f clang)
DEVICE_CFLAGS?=		-isysroot "$(DEVICE_ROOT)" -gdwarf-2 -miphoneos-version-min=3.0
DEVICE_CFLAGS_ARMV6?=	-arch armv6 -mthumb $(DEVICE_CFLAGS)
DEVICE_CFLAGS_ARMV7?=	-arch armv7 $(DEVICE_CFLAGS)


SIM_SDK?=		iPhoneSimulator5.1
SIM_PLATFORM?=		$(PLATFORMS)/iPhoneSimulator.platform
SIM_ROOT?=		$(SIM_PLATFORM)/Developer/SDKs/$(SIM_SDK).sdk
SIM_GCC?=		$(shell xcrun -sdk `echo ${SIM_SDK} | tr '[A-Z]' '[a-z]'` -f clang)
SIM_CFLAGS?=		-arch i386 -isysroot "$(SIM_ROOT)" -mmacosx-version-min=10.6 -gdwarf-2

MAC_SDK?=		MacOSX10.7
MAC_PLATFORM?=		$(PLATFORMS)/MacOSX.platform
MAC_ROOT?=		$(MAC_PLATFORM)/Developer/SDKs/$(MAC_SDK).sdk
MAC_GCC?=		$(shell xcrun -sdk `echo ${MAC_SDK} | tr '[A-Z]' '[a-z]'` -f clang)
MAC_CFLAGS?=		-arch x86_64 -arch i386 -isysroot "$(MAC_ROOT)" -mmacosx-version-min=10.6 -gdwarf-2

IOS_OBJS=		sqlite3-sim.o \
			sqlite3-ios-armv6.o \
			sqlite3-ios-armv7.o

MAC_OBJS=		sqlite3-macosx.o

PRODUCTS=		$(IOS_PRODUCT) $(MAC_PRODUCT)
IOS_PRODUCT=		libplsqlite3-ios.a
MAC_PRODUCT=		libplsqlite3-macosx.a

all: $(PRODUCTS)

sqlite3-sim.o: sqlite3.c
	$(SIM_GCC) $(CFLAGS) $(SIM_CFLAGS) -c $< -o $@

sqlite3-ios-armv6.o: sqlite3.c
	$(DEVICE_GCC) $(CFLAGS) $(DEVICE_CFLAGS_ARMV6) -c $< -o $@

sqlite3-ios-armv7.o: sqlite3.c
	$(DEVICE_GCC) $(CFLAGS) $(DEVICE_CFLAGS_ARMV7) -c $< -o $@

sqlite3-macosx.o: sqlite3.c
	$(MAC_GCC) $(CFLAGS) $(MAC_CFLAGS) -c $< -o $@

$(MAC_PRODUCT): $(MAC_OBJS)
	/usr/bin/libtool -static $+ -o $@

$(IOS_PRODUCT): $(IOS_OBJS)
	/usr/bin/libtool -static $+ -o $@

clean-objs:
	rm -f $(IOS_OBJS) $(MAC_OBJS)

clean: clean-objs
	rm -f $(PRODUCTS)
