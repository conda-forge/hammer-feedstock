#!/usr/bin/env bash
set -exu

mkdir build
cd build

cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_LIBDIR=lib \
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

# The wheel build/install runs inside a CMake execute_process() that swallows
# errors, so verify the module actually landed instead of failing later as an
# ImportError in the test phase.
site_packages=$("$PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
if [[ ! -d "${site_packages}/hammer" ]]; then
    echo "ERROR: the 'hammer' Python module was not installed into ${site_packages}" >&2
    exit 1
fi
