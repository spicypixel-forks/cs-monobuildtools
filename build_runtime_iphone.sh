#!/bin/sh
SDK_VERSION=6.1
MAC_SDK_VERSION=10.6
ASPEN_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer
SIMULATOR_ASPEN_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer
XCOMP_ASPEN_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${MAC_SDK_VERSION}.sdk

if [ ! -d $ASPEN_ROOT/SDKs/iPhoneOS${SDK_VERSION}.sdk ]; then
	SDK_VERSION=5.1
fi

echo "Using SDK $SDK_VERSION"

ASPEN_SDK=$ASPEN_ROOT/SDKs/iPhoneOS${SDK_VERSION}.sdk/
SIMULATOR_ASPEN_SDK=$SIMULATOR_ASPEN_ROOT/SDKs/iPhoneSimulator${SDK_VERSION}.sdk

ORIG_PATH=$PATH
PRFX=$PWD/tmp 
ROOT=$PWD
MONOROOT=$PWD/../Mono

if [ ${UNITY_THISISABUILDMACHINE:+1} ]; then
        echo "Erasing builds folder to make sure we start with a clean slate"
        rm -rf builds
fi

setenv () {
	export PATH=$ASPEN_ROOT/usr/bin:$PATH

	export C_INCLUDE_PATH="$ASPEN_SDK/usr/lib/gcc/arm-apple-darwin9/4.2.1/include:$ASPEN_SDK/usr/include"
	export CPLUS_INCLUDE_PATH="$ASPEN_SDK/usr/lib/gcc/arm-apple-darwin9/4.2.1/include:$ASPEN_SDK/usr/include"
	#export CFLAGS="-DZ_PREFIX -DPLATFORM_IPHONE -DARM_FPU_VFP=1 -miphoneos-version-min=3.0 -mno-thumb -fvisibility=hidden -g -O0"
	export CFLAGS="-DHAVE_ARMV6=1 -DZ_PREFIX -DPLATFORM_IPHONE -DARM_FPU_VFP=1 -miphoneos-version-min=3.0 -mno-thumb -fvisibility=hidden -Os"
	export CXXFLAGS="$CFLAGS"
	export CC="gcc -arch $1"
	export CXX="g++ -arch $1"
	export CPP="cpp -nostdinc -U__powerpc__ -U__i386__ -D__arm__"
	export CXXPP="cpp -nostdinc -U__powerpc__ -U__i386__ -D__arm__"
	export LD=$CC
	export LDFLAGS="-liconv -Wl,-syslibroot,$ASPEN_SDK"
}

unsetenv () {
	export PATH=$ORIG_PATH

	unset C_INCLUDE_PATH
	unset CPLUS_INCLUDE_PATH
	unset CC
	unset CXX
	unset CPP
	unset CXXPP
	unset LD
	unset LDFLAGS
	unset PLATFORM_IPHONE_XCOMP
	unset CFLAGS
	unset CXXFLAGS
}

export mono_cv_uscore=yes
export mono_cv_clang=no
export cv_mono_sizeof_sunpath=104
export ac_cv_func_posix_getpwuid_r=yes
export ac_cv_func_backtrace_symbols=no
#export interpreter_dir=interpreter

build_arm_mono ()
{
	setenv "$1"

	cd "$MONOROOT"
	# make clean
	# rm config.h*
	# 
	# pushd eglib 
	# ./autogen.sh --host=arm-apple-darwin9 --prefix=$PRFX
	# make clean
	# popd
	# 
	# ./autogen.sh --prefix=$PRFX --disable-mcs-build --host=arm-apple-darwin9 --disable-shared-handles --with-tls=pthread --with-sigaltstack=no --with-glib=embedded --enable-minimal=jit,profiler,com --disable-nls --with-sgen=yes || exit 1
	# perl -pi -e 's/MONO_SIZEOF_SUNPATH 0/MONO_SIZEOF_SUNPATH 104/' config.h
	# perl -pi -e 's/#define HAVE_FINITE 1//' config.h
	# #perl -pi -e 's/#define HAVE_MMAP 1//' config.h
	# perl -pi -e 's/#define HAVE_CURSES_H 1//' config.h
	# perl -pi -e 's/#define HAVE_STRNDUP 1//' eglib/config.h

	pushd eglib
	make
	popd
	
	pushd libgc
	make
	popd

	pushd mono
	# (pushd utils && make && popd) || exit 1
	# (pushd io-layer && make && popd) || exit 1
	# (pushd metadata && make && popd) || exit 1
	# (pushd arch && make && popd) || exit 1
	# (pushd mini && make && popd) || exit 1
	# popd
	# 
	# 
		pushd utils
			make
		popd
		pushd io-layer
			make
		popd
		pushd metadata
			make
		popd
		pushd arch
			make
		popd
		pushd mini
			make
		popd
	popd
	# exit 1

	mkdir -p "$ROOT/builds/embedruntimes/iphone"
	cp "$MONOROOT/mono/mini/.libs/libmonoboehm-2.0.a" "$ROOT/builds/embedruntimes/iphone/libmono-2.0-$1.a" || exit 1
	cp "$MONOROOT/mono/mini/.libs/libmonosgen-2.0.a" "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-$1.a" || exit 1
}

build_iphone_runtime () 
{
	echo "Building iPhone runtime"
	build_arm_mono "armv7s" || exit 1
	build_arm_mono "armv7" || exit 1

	libtool -static -o "$ROOT/builds/embedruntimes/iphone/libmono-2.0-arm.a" "$ROOT/builds/embedruntimes/iphone/libmono-2.0-armv7.a" "$ROOT/builds/embedruntimes/iphone/libmono-2.0-armv7s.a" || exit 1
	rm "$ROOT/builds/embedruntimes/iphone/libmono-2.0-armv7.a"
	rm "$ROOT/builds/embedruntimes/iphone/libmono-2.0-armv7s.a"
	libtool -static -o "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-arm.a" "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-armv7.a" "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-armv7s.a" || exit 1
	rm "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-armv7.a"
	rm "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-armv7s.a"
	unsetenv
	echo "iPhone runtime build done"
}

build_iphone_crosscompiler ()
{
	echo "Building iPhone cross compiler";
	export CFLAGS="-DARM_FPU_VFP=1 -DUSE_MUNMAP -DPLATFORM_IPHONE_XCOMP"	
	export CC="gcc -arch i386"
	export CXX="g++ -arch i386"
	export CPP="$CC -E"
	export LD=$CC
	export MACSDKOPTIONS="-D_XOPEN_SOURCE -mmacosx-version-min=$MAC_SDK_VERSION -isysroot $XCOMP_ASPEN_ROOT"

	export PLATFORM_IPHONE_XCOMP=1	
	cd $MONOROOT

	pushd eglib 
	./autogen.sh --prefix=$PRFX || exit 1
	make clean
	popd
	
	./autogen.sh --prefix=$PRFX --with-macversion=$MAC_SDK_VERSION --disable-mcs-build --disable-shared-handles --with-tls=pthread --with-signalstack=no --with-glib=embedded --target=arm-darwin --disable-nls || exit 1
	perl -pi -e 's/#define HAVE_STRNDUP 1//' eglib/config.h
	make clean || exit 1
	make || exit 1
	mkdir -p "$ROOT/builds/crosscompiler/iphone"
	cp "$MONOROOT/mono/mini/mono" "$ROOT/builds/crosscompiler/iphone/mono-xcompiler"
	cp "$MONOROOT/mono/mini/mono-sgen" "$ROOT/builds/crosscompiler/iphone/mono-sgen-xcompiler"
	unsetenv
	echo "iPhone cross compiler build done"
}

build_iphone_simulator ()
{
	echo "Building iPhone simulator static lib";
	export MACSYSROOT="-isysroot $SIMULATOR_ASPEN_SDK"
	export MACSDKOPTIONS="-miphoneos-version-min=3.0 $MACSYSROOT"
	export CC="$SIMULATOR_ASPEN_ROOT/usr/bin/gcc -arch i386"
	export CPP="$CC -E"
	export CXX="$SIMULATOR_ASPEN_ROOT/usr/bin/g++ -arch i386"
	export LIBTOOLIZE=`which glibtoolize`
	cd "$ROOT"
	perl build_runtime_osx.pl -iphone_simulator=1 || exit 1
	echo "Copying iPhone simulator static lib to final destination";
	mkdir -p "$ROOT/builds/embedruntimes/iphone"
	cp "$MONOROOT/mono/mini/.libs/libmono-2.0.a" "builds/embedruntimes/iphone/libmono-2.0-i386.a"
	cp "$MONOROOT/mono/mini/.libs/libmonosgen-2.0.a" "builds/embedruntimes/iphone/libmonosgen-2.0-i386.a"
	unsetenv
}

build_iphone_universal ()
{
	echo "Building iPhone universal static lib"
	libtool -static -o "$ROOT/builds/embedruntimes/iphone/libmono-2.0.a" "$ROOT/builds/embedruntimes/iphone/libmono-2.0-arm.a" "$ROOT/builds/embedruntimes/iphone/libmono-2.0-i386.a" || exit 1
	libtool -static -o "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0.a" "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-arm.a" "$ROOT/builds/embedruntimes/iphone/libmonosgen-2.0-i386.a" || exit 1
}

usage()
{
	echo "available arguments: [--runtime-only|--xcomp-only|--simulator-only]";
}

if [ $# -gt 1 ]; then
 	usage
	exit 1
fi
if [ $# -eq 1 ]; then
	if [ "x$1" == "x--runtime-only" ]; then
		build_iphone_runtime || exit 1
	elif [ "x$1" == "x--xcomp-only" ]; then
		build_iphone_crosscompiler || exit 1	
	elif [ "x$1" == "x--simulator-only" ]; then
		build_iphone_simulator|| exit 1	
	else
		usage
	fi
fi
if [ $# -eq 0 ]; then
	build_iphone_runtime || exit 1
	build_iphone_simulator || exit 1
	build_iphone_universal || exit 1
	build_iphone_crosscompiler || exit 1
fi
if [ ${UNITY_THISISABUILDMACHINE:+1} ]; then
	echo "mono-runtime-iphone = $BUILD_VCS_NUMBER_mono_unity_2_10_2" > $ROOT/builds/versions.txt
fi
