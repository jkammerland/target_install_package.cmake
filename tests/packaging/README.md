# Packaging Tests

This directory contains Docker-based tests for verifying package installation across different Linux distributions.

## Overview

The testing framework supports two packaging approaches:
1. **CPack-based packages** (DEB for Ubuntu, RPM for Fedora) - Fully functional and tested
2. **Universal packaging templates** (PKGBUILD for Arch, APKBUILD for Alpine, Nix expressions) - Templates only, require customization

### Important Note on Universal Packaging

The universal packaging templates are **template files** with placeholder values. They are not meant to be directly buildable without customization. Current limitations:

- Source URLs use placeholder values (e.g., `https://github.com/example/cpack_lib`)
- Templates require user customization before use
- The test suite currently **skips these tests** as they're testing templates, not actual packages
- Future improvements may include generating test-ready templates or more complete package generation

For production use, users should:
1. Replace placeholder URLs with actual source locations
2. Update checksums with real values
3. Customize metadata (maintainer, license, etc.)
4. Test the customized templates in their target environments

## Directory Structure

```
tests/packaging/
├── docker/              # Docker containers for each distribution
│   ├── ubuntu/         # Ubuntu/Debian test container
│   ├── fedora/         # Fedora/RHEL test container
│   ├── alpine/         # Alpine Linux test container
│   ├── arch/           # Arch Linux test container
│   └── nix/            # NixOS test container
├── build-packages.sh   # Script to build all package types
├── test-packages.sh    # Script to test packages in containers
└── packages/           # Generated packages (created by build-packages.sh)
```

## Usage

### 1. Build Packages

First, generate all package types:

```bash
./build-packages.sh
```

This will:
- Build the `cpack-basic` example project
- Generate DEB and RPM packages using CPack
- Generate universal packaging templates for Arch, Alpine, and Nix
- Create a source tarball for source-based packaging

### 2. Test Packages

Test a specific distribution:

```bash
./test-packages.sh ubuntu   # Test DEB package on Ubuntu
./test-packages.sh fedora   # Test RPM package on Fedora
./test-packages.sh alpine   # Test APKBUILD on Alpine
./test-packages.sh arch     # Test PKGBUILD on Arch Linux
./test-packages.sh nix      # Test Nix expression
```

Or test all distributions:

```bash
./test-packages.sh all
```

## How It Works

### CPack-based Testing (Ubuntu/Fedora)

1. The container mounts the pre-built package (`.deb` or `.rpm`)
2. Installs the package using the native package manager
3. Verifies installation by checking for:
   - Runtime libraries
   - Development headers
   - Executables
   - Package metadata

### Universal Packaging Testing (Alpine/Arch/Nix)

1. The container mounts the packaging template directory
2. Builds the package from source using the template
3. Installs the built package
4. Performs the same verification steps

## Requirements

- Docker
- CMake 3.25+
- A C++ compiler

## Adding New Distributions

To add support for a new distribution:

1. Create a new Docker container in `docker/<distro>/`
2. Add a `Dockerfile` that sets up the build environment
3. Add a `test.sh` script that handles package installation and verification
4. Update `test-packages.sh` to include the new distribution
5. If using universal packaging, add support in `target_configure_universal_packaging.cmake`

## Troubleshooting

### Docker Permission Issues

If you encounter permission errors, ensure Docker is properly configured:

```bash
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

### Package Build Failures

Check the `packages/` directory to ensure packages were generated:

```bash
ls -la packages/
```

### Container Build Failures

Rebuild Docker images with:

```bash
docker build -t target-install-package-test:ubuntu docker/ubuntu/
```

## CI Integration

These tests can be integrated into CI by running:

```bash
# In CI workflow
./tests/packaging/build-packages.sh
./tests/packaging/test-packages.sh all
```

The scripts return 0 on success and 1 on failure, making them suitable for CI pipelines.