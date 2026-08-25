# CPack AppImage example

This example opts in to CMake's native AppImage generator through `export_cpack(GENERATORS AppImage)`. It installs an executable, a shared library, desktop metadata, an icon, and unrelated Development and Documentation payload to demonstrate AppImage's monolithic component behavior. `Documentation` is deliberately absent from `export_cpack(COMPONENTS ...)`, but CPack still includes it because AppImage does not support component filtering.

See [AppImage Packaging](../../docs/AppImage-Packaging.md) for prerequisites and reproducible commands. The proof suite supplies pinned `appimagetool`, `patchelf`, and runtime paths through the cache variables declared in `CMakeLists.txt`.
