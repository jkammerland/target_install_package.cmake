# Add this function to your project
function(target_configure_sources TARGET_NAME)
  set(options "")
  set(oneValueArgs DESTINATION)
  set(multiValueArgs INTERFACE PUBLIC PRIVATE)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Process each scope
  foreach(SCOPE INTERFACE PUBLIC PRIVATE)
    if(ARGS_${SCOPE})
      # Store configure sources with their scope
      set_property(
        TARGET ${TARGET_NAME}
        APPEND
        PROPERTY ${SCOPE}_CONFIGURE_SOURCES ${ARGS_${SCOPE}})
    endif()
  endforeach()

  # Store destination if provided
  if(ARGS_DESTINATION)
    set_property(TARGET ${TARGET_NAME} PROPERTY CONFIGURE_DESTINATION ${ARGS_DESTINATION})
  endif()
endfunction()
