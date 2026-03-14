# Packaging Tests

This directory contains container-based checks for the generated packaging artifacts.

## Overview

The current test coverage has two categories:
1. **Generated CPack packages** (DEB for Ubuntu, RPM for Fedora), which are built and install-tested.
2. **Placeholder distro entries** (Alpine, Arch, Nix), which exist to reserve future source-packaging coverage and are currently reported as skipped.

## Directory Structure

```
tests/packaging/
├── docker/              # Docker containers for each distribution
│   ├── ubuntu/         # Ubuntu/Debian test container
│   ├── fedora/         # Fedora/RHEL test container
│   ├── alpine/         # Alpine Linux test container
│   ├── arch/           # Arch Linux test container
│   └── nix/            # NixOS test container
├── build-packages.sh   # Script to build the generated package artifacts
├── test-packages.sh    # Script to test packages in containers
└── packages/           # Generated packages (created by build-packages.sh)
```

## Usage

### 1. Build Packages

First, generate the packages used by the tests:

```bash
./build-packages.sh
```

This will:
- Build the `cpack-basic` example project
- Generate DEB and RPM packages using CPack
- Copy the generated package artifacts into `build/packaging/packages`

### 2. Test Packages

Test a specific distribution:

```bash
./test-packages.sh ubuntu   # Test DEB package on Ubuntu
./test-packages.sh fedora   # Test RPM package on Fedora
./test-packages.sh alpine   # Placeholder path, currently skipped
./test-packages.sh arch     # Placeholder path, currently skipped
./test-packages.sh nix      # Placeholder path, currently skipped
```

Or test all distributions:

```bash
./test-packages.sh all
```

## How It Works

### Supported Install Tests (Ubuntu/Fedora)

1. The container mounts the pre-built package (`.deb` or `.rpm`)
2. Installs the package using the native package manager
3. Verifies installation by checking for:
   - Runtime libraries
   - Development headers
   - Executables
   - Package metadata

### Placeholder Distro Entries (Alpine/Arch/Nix)

1. The distro name remains available in the CLI and CI summary output
2. The test run records the distro as skipped
3. No package is built or installed for these distros yet

## Requirements

- Docker or Podman for the Ubuntu/Fedora install tests
- CMake 3.25+
- A C++ compiler

## Adding New Distributions

To add support for a new distribution:

1. Create a new Docker container in `docker/<distro>/`
2. Add a `Dockerfile` that sets up the build environment
3. Add a `test.sh` script that handles package installation and verification
4. Update `test-packages.sh` to include the new distribution
5. Add a real package-generation and installation flow before enabling it in `test-packages.sh`

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
