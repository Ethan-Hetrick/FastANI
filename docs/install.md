# Installation

FastANI is usually built from source with CMake.

## Recommended build

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(nproc)" --target fastANI
```

This produces the executable at `build/fastANI`.

## Install system-wide

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(nproc)"
cmake --install build
```

## Notes

- `Release` is recommended for benchmarking and production use.
- `RelWithDebInfo` can be useful when you want optimized performance with debug symbols.
- If you are building inside a managed workflow, keep the CMake build type, compiler, and FastANI version recorded with your analysis outputs.
