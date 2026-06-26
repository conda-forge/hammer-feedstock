#!/usr/bin/env bash
set -exu

mkdir build
cd build

# Hammer installs its libraries into the lib/Hammer/ subdirectory rather than
# lib/, so consumers need that directory on their RPATH. Build shared libraries
# and bake the install RPATH into every binary -- including libpyHammer, which is
# copied out of the build tree into the wheel, so it must already carry the final
# RPATH (CMAKE_BUILD_WITH_INSTALL_RPATH) to find the Hammer .so/.dylib from
# site-packages at import time.
cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_INSTALL_RPATH="${PREFIX}/lib;${PREFIX}/lib/Hammer" \
    -DWITH_PYTHON=ON \
    -DWITH_ROOT=ON \
    -DWITH_EXAMPLES=ON \
    -DWITH_EXAMPLES_EXTRA=OFF \
    -DENABLE_TESTS=OFF \
    -DBUILD_DOCUMENTATION=OFF \
    -DINSTALL_EXTERNAL_DEPENDENCIES=OFF \
    -DFORCE_YAMLCPP_INSTALL=OFF \
    -DFORCE_HEPMC_INSTALL=OFF \
    -DPython3_EXECUTABLE="$PYTHON" \
    ..

# Hammer silently downgrades to a C++-only build (WITH_PYTHON OFF) if its Python
# build tooling is missing, so assert the bindings stayed enabled before building.
grep -q '^WITH_PYTHON:BOOL=ON$' CMakeCache.txt || {
    echo "ERROR: Hammer disabled its Python bindings during CMake configure" >&2
    exit 1
}

make -j${CPU_COUNT}
make install

# Remove the ROOT-style environment setup scripts. They are redundant in a conda
# environment (activation + RPATHs already make Hammer importable and linkable),
# and they bake in the prefix and force PYTHONPATH / DYLD_LIBRARY_PATH, which can
# shadow or break the surrounding environment if sourced. (thisroot.* belongs to
# ROOT and is intentionally left untouched.)
rm -f "$PREFIX"/bin/thishammer.* "$PREFIX"/bin/thisrootalias.sh

# The wheel build/install runs inside a CMake execute_process() that swallows
# errors, so verify the module actually landed instead of failing later as an
# ImportError in the test phase.
site_packages=$("$PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
if [[ ! -d "${site_packages}/hammer" ]]; then
    echo "ERROR: the 'hammer' Python module was not installed into ${site_packages}" >&2
    exit 1
fi
