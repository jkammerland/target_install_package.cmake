function(_tip_attach_source_math_modules_file_set module_dir)
  if(NOT TARGET SourceMathModules::source_math_modules)
    message(FATAL_ERROR "Expected imported target SourceMathModules::source_math_modules to exist before attaching module file set")
  endif()

  # Imported INTERFACE targets do not preserve CXX_EXTENSIONS, so force the
  # module BMI to use the same non-GNU C++20 mode as downstream consumers.
  target_compile_options(
    SourceMathModules::source_math_modules
    INTERFACE "$<$<COMPILE_LANG_AND_ID:CXX,AppleClang,Clang,GNU>:-std=c++20>")

  target_sources(
    SourceMathModules::source_math_modules
    INTERFACE FILE_SET
              CXX_MODULES
              BASE_DIRS
              "${module_dir}"
              FILES
              "${module_dir}/source_math.cppm")
endfunction()

set(_tip_source_math_modules_module_dir "${PACKAGE_PREFIX_DIR}/include/source_math_modules/modules")
cmake_language(DEFER CALL _tip_attach_source_math_modules_file_set "${_tip_source_math_modules_module_dir}")
