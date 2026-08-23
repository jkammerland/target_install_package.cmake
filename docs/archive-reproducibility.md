# Archive Reproducibility

The deterministic archive proof is pinned to CMake and CPack 4.4.2 with the built-in `TGZ` generator. It creates two clean build trees from the same sources and compares SHA-256 digests of their archives.

Use this environment for the same contract:

```sh
export SOURCE_DATE_EPOCH=1704067200
export TZ=UTC
export LC_ALL=C
export LANG=C
cmake -S . -B build
cmake --build build
cpack -G TGZ --config build/CPackConfig.cmake -B packages
```

The proof fixes `CPACK_ARCHIVE_THREADS=1`, includes source and configure-generated files, and compares the final compressed archive. Before the second clean build, it rewrites identical payload content after a time boundary and asserts that both source and generated-file mtimes differ. Matching archives therefore exercise timestamp normalization instead of relying on coincidentally equal input timestamps. A mismatch prints verbose archive metadata so timestamp, ordering, ownership, encoding, or compression drift is visible.

This is a CPack 4.4.2 `TGZ` proof only. Native package generators, ZIP, external archive tools, symlinks, file modes, and other filesystem-specific metadata are outside this guarantee. Keep `SOURCE_DATE_EPOCH` fixed and use UTF-8 package inputs when reproducibility is required.
