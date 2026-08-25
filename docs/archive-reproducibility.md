# Archive Reproducibility

The deterministic archive proof is pinned to CMake and CPack 4.4.2 with the built-in `TGZ` generator. It creates two clean build trees from the same sources and compares SHA-256 digests of their archives. Configure the package with fixed numeric ownership as part of that contract:

```cmake
export_cpack(
  GENERATORS TGZ
  ARCHIVE_UID 0
  ARCHIVE_GID 0
  ADDITIONAL_CPACK_VARS
    CPACK_ARCHIVE_THREADS 1
)
```

Use this environment for the same contract:

```sh
export SOURCE_DATE_EPOCH=1704067200
export TZ=UTC
export LC_ALL=C
export LANG=C
cmake -S . -B build \
  -DTARGET_INSTALL_PACKAGE_ENABLE_CPACK=ON
cmake --build build
cpack -G TGZ --config build/CPackConfig.cmake -B packages
```

The proof fixes ownership at `0/0` and `CPACK_ARCHIVE_THREADS=1`, then compares archives created from inputs with different timestamps.

`ARCHIVE_UID` and `ARCHIVE_GID` require CMake 4.3 and accept values from `0` through `2147483647`. Tar and ZIP store these IDs; other generators may ignore them. Matching `ADDITIONAL_CPACK_VARS` entries override the validated arguments.

This guarantee covers CPack 4.4.2 `TGZ` output only. Keep `SOURCE_DATE_EPOCH` fixed and use UTF-8 package inputs.
