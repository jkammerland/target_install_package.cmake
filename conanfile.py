from conan import ConanFile
from conan.errors import ConanInvalidConfiguration
from conan.tools.cmake import CMake, cmake_layout
from conan.tools.files import copy, load
import os
import re


class TargetInstallPackageConan(ConanFile):
    name = "target_install_package"
    license = "MIT"
    url = "https://github.com/jkammerland/target_install_package.cmake"
    homepage = "https://github.com/jkammerland/target_install_package.cmake"
    description = "CMake utilities for install/export/package configuration."
    topics = ("cmake", "packaging", "install", "export", "cpack")
    package_type = "header-library"
    settings = "os", "arch", "compiler", "build_type"
    generators = "CMakeToolchain"
    exports_sources = (
        "CMakeLists.txt",
        "cmake/*",
        "export_cpack.cmake",
        "target_configure_sources.cmake",
        "target_install_package.cmake",
        "LICENSE",
    )
    no_copy_source = True

    def set_version(self):
        cmakelists = load(self, os.path.join(self.recipe_folder, "CMakeLists.txt"))
        match = re.search(r"project\(target_install_package VERSION ([0-9]+\.[0-9]+\.[0-9]+)\)", cmakelists)
        if not match:
            raise ConanInvalidConfiguration("Unable to parse project version from CMakeLists.txt")
        self.version = match.group(1)

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure(
            variables={
                "TARGET_INSTALL_PACKAGE_ENABLE_INSTALL": True,
                "TARGET_INSTALL_PACKAGE_DISABLE_INSTALL": False,
                "target_install_package_BUILD_TESTS": False,
            }
        )
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

        copy(self, "LICENSE", src=self.source_folder, dst=os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "target_install_package")
        self.cpp_info.set_property("cmake_target_name", "target_install_package::target_install_package")
        self.cpp_info.set_property(
            "cmake_build_modules",
            [
                os.path.join("share", "cmake", "target_install_package", "list_file_include_guard.cmake"),
                os.path.join("share", "cmake", "target_install_package", "project_include_guard.cmake"),
                os.path.join("share", "cmake", "target_install_package", "project_log.cmake"),
                os.path.join("share", "cmake", "target_install_package", "target_configure_sources.cmake"),
                os.path.join("share", "cmake", "target_install_package", "target_install_package.cmake"),
                os.path.join("share", "cmake", "target_install_package", "export_cpack.cmake"),
            ],
        )

        self.cpp_info.bindirs = []
        self.cpp_info.libdirs = []
        self.cpp_info.includedirs = []
        self.cpp_info.builddirs = [os.path.join("share", "cmake", "target_install_package")]
