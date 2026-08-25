# Multiple-Component Installs

CMake 4.4 accepts multiple names after `cmake --install --component`:

```bash
cmake --install build \
  --component Runtime Development \
  --prefix "$PWD/stage"
```

Repeating `--component` is equivalent. CMake 3.25 through 4.3 require one invocation per component.

Selected components do not pull in dependencies. Duplicate names run their install rules repeatedly, and unknown names are ignored. Omitting `--component` installs every non-`EXCLUDE_FROM_ALL` rule.

Released CMake 4.4.0 through 4.4.2 can return success after a component fails. Track [CMake issue 27906](https://gitlab.kitware.com/cmake/cmake/-/issues/27906) and use separate serial invocations until a fixed release is available:

```bash
cmake --install build --component Runtime --prefix "$PWD/stage" &&
  cmake --install build --component Development --prefix "$PWD/stage"
```

This is a direct `cmake --install` feature. CPack component selection remains configured through `export_cpack()`.
