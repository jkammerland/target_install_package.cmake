list_file_include_guard(VERSION 1.1.0)

set_property(GLOBAL PROPERTY PROJECT_LOG_INITIALIZED true)

# ~~~
# project_log(Level Arg1 Arg2 ...)
#
#
# Level is the same as standard cmake, and is summerized in the following table:
#
# | Level | Description |
# |-------|-------------|
# | `FATAL_ERROR`      | Stops processing & generation. Makes cmake exit with non-zero code.
# | `SEND_ERROR`       | Reports error, continues processing but skips generation.
# | `WARNING`          | Shows warning message, continues processing.
# | `AUTHOR_WARNING`   | Developer warning, continues processing.
# | `DEPRECATION`      | Shows deprecation notice if `CMAKE_ERROR/WARN_DEPRECATED` enabled.
# | `NOTICE` or (none) | Important message printed to stderr.
# | `STATUS`           | Key information users might need, ideally brief.
# | `VERBOSE`          | Additional details for interested users.
# | `DEBUG`            | Implementation details for project developers.
# | `TRACE`            | Temporary fine-grained messages about internal details.
# ~~~
function(project_log level)
  # Determine project context name
  if(PROJECT_NAME)
    set(_log_context_name "${PROJECT_NAME}")
  else()
    set(_log_context_name "CMake") # Default context if PROJECT_NAME is not set
  endif()

  # Collect all the arguments after 'level' into a single message
  string(JOIN " " _message_content ${ARGN})
  set(msg "") # Initialize msg
  if(NOT _message_content STREQUAL "")
    set(msg " ${_message_content}") # Prepend space if there's content, to match original format
  endif()

  # Define ANSI color codes for different log levels (using CMake-compatible escapes)
  if(WIN32)
    # Windows terminals might not support ANSI colors by default Setting them to empty effectively disables them for Windows here.
    set(COLOR_RESET "")
    set(COLOR_STATUS "")
    set(COLOR_VERBOSE "")
    set(COLOR_DEBUG "")
    set(COLOR_TRACE "")
    set(COLOR_WARNING "")
    set(COLOR_AUTHOR_WARNING "")
    set(COLOR_DEPRECATION "")
    set(COLOR_NOTICE "")
    set(COLOR_ERROR "")
    set(COLOR_FATAL_ERROR "")
  else()
    # Define ANSI color codes for different log levels (using CMake-compatible escapes)
    string(ASCII 27 Esc)
    set(ColourReset "${Esc}[m")
    set(ColourBold "${Esc}[1m")
    set(Red "${Esc}[31m")
    set(Green "${Esc}[32m")
    set(Yellow "${Esc}[33m")
    set(Blue "${Esc}[34m")
    set(Magenta "${Esc}[35m")
    set(Cyan "${Esc}[36m")
    set(White "${Esc}[37m")
    set(BoldRed "${Esc}[1;31m")
    set(BoldGreen "${Esc}[1;32m")
    set(BoldYellow "${Esc}[1;33m")
    set(BoldBlue "${Esc}[1;34m")
    set(BoldMagenta "${Esc}[1;35m")
    set(BoldCyan "${Esc}[1;36m")
    set(BoldWhite "${Esc}[1;37m")

    # Map the new color variables to the COLOR_* variables used in the existing code
    set(COLOR_RESET "${ColourReset}")
    set(COLOR_STATUS "${Green}") # green
    set(COLOR_VERBOSE "${BoldGreen}") # bold green
    set(COLOR_DEBUG "${BoldBlue}") # bold blue
    set(COLOR_TRACE "${Cyan}") # cyan
    set(COLOR_WARNING "${BoldYellow}") # bold yellow
    set(COLOR_AUTHOR_WARNING "${Yellow}") # yellow
    set(COLOR_DEPRECATION "${BoldMagenta}") # bold magenta
    set(COLOR_NOTICE "${White}") # light gray
    set(COLOR_ERROR "${BoldRed}") # bold red
    set(COLOR_FATAL_ERROR "${Esc}[1;41;37m") # white on red background (keeping original as no direct equivalent)
  endif()

  if(PROJECT_LOG_COLORS)
    # Select color based on log level
    if(DEFINED COLOR_${level})
      set(level_color "${COLOR_${level}}")
    else()
      set(level_color "${COLOR_RESET}") # Default to reset if level-specific color not found
    endif()

    # Construct the full message with project name and colored level
    set(full_msg "[${_log_context_name}][${level_color}${level}${COLOR_RESET}]${msg}")
  else()
    set(full_msg "[${_log_context_name}][${level}]${msg}")
  endif()

  # Forward the message with the specified log level
  message(${level} "${full_msg}")
endfunction()
