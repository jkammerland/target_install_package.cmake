# Example-internal verification only.
# Consumers of the installed package should not need to understand this logic.

get_target_property(_sdk_runtime_target Sdk::sdk_runtime ALIASED_TARGET)
if(_sdk_runtime_target)
  set(_sdk_runtime_check_target "${_sdk_runtime_target}")
else()
  set(_sdk_runtime_check_target "Sdk::sdk_runtime")
endif()

get_target_property(_sdk_runtime_imported "${_sdk_runtime_check_target}" IMPORTED)
if(NOT _sdk_runtime_imported)
  message(FATAL_ERROR "Sdk::sdk_runtime is expected to stay imported from the install tree")
endif()
