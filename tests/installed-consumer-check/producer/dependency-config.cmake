if(NOT TARGET tip_check_dependency::value)
  add_library(tip_check_dependency::value INTERFACE IMPORTED)
  set_target_properties(tip_check_dependency::value PROPERTIES INTERFACE_COMPILE_DEFINITIONS "DEPENDENCY_VALUE=42")
endif()
