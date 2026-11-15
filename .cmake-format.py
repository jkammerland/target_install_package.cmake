with section("format"):
  # How wide to allow formatted cmake files
  line_width = 200

  # Lowercase builtin commands; module commands such as FetchContent_Declare keep their documented spelling
  command_case = "canonical"

with section("markup"):
  # Enable/disable formatting of comments
  enable_markup = False
