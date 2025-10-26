## Basic Symbol Stripping Example

This minimal project installs a shared library and companion CLI twice—once as `Debug` and once as `RelWithDebInfo`—into the same prefix. It keeps both variants side by side by applying a debug postfix and demonstrates how to strip the binaries while preserving usable symbols for debugging.

### Build & Install

```bash
cmake -S . -B build-debug -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DTIP_INSTALL_LAYOUT=fhs
cmake --build build-debug
cmake --install build-debug --prefix install

cmake -S . -B build-relwithdebinfo -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DTIP_INSTALL_LAYOUT=fhs
cmake --build build-relwithdebinfo
cmake --install build-relwithdebinfo --prefix install
```

After both installs the prefix contains:

- `install/lib64/libvector_mathd.so` (Debug) and `install/lib64/libvector_math.so` (RelWithDebInfo).
- `install/bin/vector_toold` (Debug) and `install/bin/vector_tool` (RelWithDebInfo).
- `install/share/cmake/vector_math` and `install/share/cmake/vector_tool` package config sets.

Both targets call `target_install_package` with the default `TIP_INSTALL_LAYOUT=fhs`, so `cmake --install` writes the library, executable, headers, and config files into a single prefix without configuration subdirectories. The debug postfix (`d`) keeps the configuration variants distinct inside the same directories.

### Strip & Preserve Symbols

Use the helper script (requires `objcopy` or `llvm-objcopy`) to generate `.dbg` files and add `GNU debuglink` entries:

```bash
./scripts/strip_with_debuglink.sh install/bin/vector_toold
./scripts/strip_with_debuglink.sh install/bin/vector_tool
```

Each invocation creates `<binary>.dbg` next to the binary, strips the binary in place, and attaches the debuglink so tools like `gdb`/`lldb` can find symbols automatically. Verify with:

```bash
readelf --string-dump=.gnu_debuglink install/bin/vector_tool
readelf --string-dump=.gnu_debuglink install/bin/vector_toold
```

`target_install_package` does not manage `.dbg` sidecars automatically—run the script as part of your packaging flow and, if you want the symbol files installed, add an explicit `install(FILES ...)` step or copy them into your artifact staging area.

### Debugging

The binaries are installed with an `RPATH` pointing at `../lib64`, so they run in-place:

```bash
./install/bin/vector_tool --norm 3 4 12       # => 13.0000
./install/bin/vector_toold --dot 3 1 2 3 4 5 6 # => 32.0000
```

Attach a debugger and the `.dbg` sidecar is picked up automatically:

```bash
gdb ./install/bin/vector_tool        # uses vector_tool.dbg
gdb ./install/bin/vector_toold       # uses vector_toold.dbg
```
