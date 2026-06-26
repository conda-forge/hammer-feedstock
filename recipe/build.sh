#!/usr/bin/env bash
set -exu

mkdir build
cd build

# Build shared libraries. Hammer's own RPATH handling (corrected in
# rpath_for_shared_libs.patch) bakes the lib/Hammer location into the binaries
# and overrides command-line RPATH flags, so none are set here.
cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=ON \
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
