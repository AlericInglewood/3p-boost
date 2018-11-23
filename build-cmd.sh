#!/bin/sh

cd "`dirname "$0"`"
top="`pwd`"
stage="$top/stage"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

BOOST_VERSION="1.60.0"
BOOST_SOURCE_DIR="boost_1_60_0"

if [ -z "$AUTOBUILD" ] ; then
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="`cygpath -u "$AUTOBUILD"`"
fi

# load autbuild provided shell functions and variables
set +x
eval "`"$AUTOBUILD" source_environment`"
set -x

build_linux()
{
    prefix="$stage"
    bits="$1"
    cores=`grep '^processor' /proc/cpuinfo | wc --lines`
    shift

    mkdir -p "$prefix/lib"
    mkdir -p "$prefix/include/boost/dcoroutine/detail"

    ./bootstrap.sh --with-toolset=gcc --with-libraries="context,date_time,filesystem,program_options,regex,signals,system,thread" --without-icu
    ./b2 -j $cores -a address-model=$bits "$*" $RELEASE_BOOST_BJAM_OPTIONS --stagedir="$prefix/lib" stage
    mv "$prefix/lib/lib" "$prefix/lib/release"
    ./b2 -j $cores -a address-model=$bits "$*" $DEBUG_BOOST_BJAM_OPTIONS --prefix="$prefix" --libdir="$prefix/lib/debug" install
    cp -r "$top"/boost-coroutine/*.hpp "$prefix/include/boost/dcoroutine"
    cp -r "$top"/boost-coroutine/detail/*.hpp "$prefix/include/boost/dcoroutine/detail"
}

BOOST_BJAM_OPTIONS="--layout=tagged -sNO_BZIP2=1 link=shared threading=multi runtime-link=shared"
RELEASE_BOOST_BJAM_OPTIONS="variant=release -sZLIB_LIBPATH=$stage/packages/lib/release $BOOST_BJAM_OPTIONS"
DEBUG_BOOST_BJAM_OPTIONS="variant=debug -sZLIB_LIBPATH=$stage/packages/lib/debug $BOOST_BJAM_OPTIONS"

cd "$BOOST_SOURCE_DIR"

boost_stage_lib="stage/lib"

case "$AUTOBUILD_PLATFORM" in
    "windows")

	mkdir -p "$stage/lib/debug"
	mkdir -p "$stage/lib/release"

	cmd.exe /C bootstrap.bat
	INCLUDE_PATH=$(cygpath -m $stage/packages/include)
	ZLIB_RELEASE_PATH=$(cygpath -m $stage/packages/lib/release)
	ZLIB_DEBUG_PATH=$(cygpath -m $stage/packages/lib/debug)
	#ICU_PATH=$(cygpath -m $stage/packages)
	
	RELEASE_BJAM_OPTIONS="--toolset=msvc-10.0 include=$INCLUDE_PATH \
        -sZLIB_LIBPATH=$ZLIB_RELEASE_PATH $BOOST_BJAM_OPTIONS"
	#-sICU_PATH=$ICU_PATH
        
	./bjam variant=release address-model=32 architecture=x86 $RELEASE_BJAM_OPTIONS stage -j2

	DEBUG_BJAM_OPTIONS="--toolset=msvc-10.0 include=$INCLUDE_PATH \
        -sZLIB_LIBPATH=$ZLIB_DEBUG_PATH $BOOST_BJAM_OPTIONS"
	#-sICU_PATH=$ICU_PATH \
	./bjam variant=debug $DEBUG_BJAM_OPTIONS stage -j2

	# Move the debug libs first, then the leftover release libs
	mv ${boost_stage_lib}/*-gd.lib "$stage/lib/debug"
	mv ${boost_stage_lib}/*.lib "$stage/lib/release"

        ;;
    "darwin")
	./bootstrap.sh --prefix=$stage #--with-icu=$stage/packages

	RELEASE_BJAM_OPTIONS="include=$stage/packages/include -sZLIB_LIBPATH=$stage/packages/lib/release $BOOST_BJAM_OPTIONS"
	./bjam toolset=darwin variant=release address-model=32 architecture=x86 $RELEASE_BJAM_OPTIONS stage

	mv $boost_stage_lib/*.a "$stage_release"
	mv $boost_stage_lib/*dylib* "$stage_release"


	DEBUG_BJAM_OPTIONS="include=$stage/packages/include -sZLIB_LIBPATH=$stage/packages/lib/debug $BOOST_BJAM_OPTIONS"
	./bjam -a toolset=darwin variant=debug $DEBUG_BJAM_OPTIONS stage

	mv $boost_stage_lib/*.a "$stage_debug"
	mv $boost_stage_lib/*dylib* "$stage_debug"

        ;;
    "linux")
        build_linux 32

        ;;

    "linux64")
        build_linux 64
            #cxxflags="-fPIC -D_GLIBCXX_DEBUG"

        ;;

esac
    
#mkdir -p "$stage/include"
#cp -R boost "$stage/include"
mkdir -p "$stage/LICENSES"
cp LICENSE_1_0.txt "$stage/LICENSES/boost.txt"
echo "$BOOST_VERSION" > "$stage/package_version"

README_DIR="$stage/autobuild-bits"
README_FILE="$README_DIR/README-Version-3p-boost"
mkdir -p $README_DIR
#cat $top/.hg/hgrc|grep default |sed  -e "s/default = ssh:\/\/hg@/https:\/\//" > $README_FILE
#echo "Commit $(hg id -i)" >> $README_FILE

cd "$top"

pass

