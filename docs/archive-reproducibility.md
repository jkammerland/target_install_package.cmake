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

The proof fixes numeric ownership at `0/0` and `CPACK_ARCHIVE_THREADS=1`, includes source and configure-generated files, and compares the final compressed archive. Before the second clean build, it rewrites identical payload content after a time boundary and asserts that both source and generated-file mtimes differ. Matching archives therefore exercise timestamp normalization instead of relying on coincidentally equal input timestamps. A separate ownership proof inspects a generated TGZ and verifies the UID/GID on regular files, nested directories, and a symlink. A mismatch prints verbose archive metadata so timestamp, ordering, ownership, encoding, or compression drift is visible.

`ARCHIVE_UID` and `ARCHIVE_GID` require CMake 4.3 or newer and accept decimal integers from `0` through `2147483647`, the portable range consumed by CPack's archive generator. Set both for an explicit contract. If only one is set, CPack defaults the other to `0`. If both are omitted, `export_cpack()` does not set either variable; with this project's CMake 3.25 policy baseline, CMake 4.3 and 4.4 preserve the invoking user's ownership through CPack's `-1/-1` compatibility behavior.

CPack's Archive generator accepts the controls for all of its 7zip, tar, and ZIP variants, and the Cygwin and FreeBSD generators use the same controls. The selected format determines how ownership is encoded, and extraction tools may ignore it even when the archive stores it. Other generators, including DEB, RPM, WIX, DragNDrop, and External, ignore these controls and need their own ownership policy.

This is a CPack 4.4.2 `TGZ` reproducibility proof only. Native package generators, ZIP, external archive tools, file modes, and other filesystem-specific metadata are outside this guarantee. Archive creation records numeric ownership on every supported entry, but extraction only restores it where the platform, tool, and privileges allow. Keep `SOURCE_DATE_EPOCH` fixed and use UTF-8 package inputs when reproducibility is required.
