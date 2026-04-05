function(_tip_attach_source_math_modules_file_set module_dir)
  if(NOT TARGET SourceMathModules::source_math_modules)
    message(FATAL_ERROR "Expected imported target SourceMathModules::source_math_modules to exist before attaching module file set")
  endif()

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
