# GPG Package Signing Example 🔐

> [!WARNING]
> Experimental implementation

This example demonstrates the GPG package signing functionality added to `export_cpack()`.

**🎯 Complete GPG Integration**
- **Multi-format signing**: Automatically signs TGZ, DEB, RPM, and all other CPack formats
- **Detached signatures**: Creates `.sig` files alongside packages
- **Cryptographic checksums**: Generates SHA256 and SHA512 for integrity verification
- **Verification scripts**: Creates consumer-friendly `verify.sh` scripts
- **Seamless workflow**: Zero additional steps - signing happens during `cpack`

**Advanced Features**
- Environment variable integration (`$GPG_SIGNING_KEY`, `$GPG_PASSPHRASE_FILE`)
- CMake preset support for streamlined workflows
- Keyserver integration for public key distribution
- Passphrase file support for CI/CD automation, **In real world, only use this if you have to to. If you do, make sure the file in only readable by a very secure user and the filesystem is encrypted.**
- Cross-platform compatibility (Linux, macOS, Windows)

## Quick Start

### Basic Usage
```cmake
export_cpack(
  PACKAGE_NAME "MySignedLibrary"
  PACKAGE_VENDOR "Example Corp" 
  PACKAGE_CONTACT "support@example.com"
  # GPG Signing configuration
  GPG_SIGNING_KEY "${GPG_SIGNING_KEY}"           # From cache/environment
  GPG_PASSPHRASE_FILE "${GPG_PASSPHRASE_FILE}"   # For automated signing
  SIGNING_METHOD "detached"                      # Creates .sig files
  GPG_KEYSERVER "keyserver.ubuntu.com"
  GENERATE_CHECKSUMS                             # SHA256/SHA512
  GENERATE_VERIFICATION_SCRIPT                   # Creates verify.sh
  # Standard CPack options
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)
```

### Manual Workflow
```bash
# 1. Set up passphrase file (for keys with passphrase)
echo "your-passphrase" > .gpg_passphrase
chmod 600 .gpg_passphrase # Only user can read, nothing else

# 2. Configure with signing
cmake -B build \
  -DGPG_SIGNING_KEY="your-key-id-or-email" \
  -DGPG_PASSPHRASE_FILE="${PWD}/.gpg_passphrase"

# 3. Build and package
cmake --build build
cpack --config build/CPackConfig.cmake

# 4. Verify results
ls -la *.tar.gz* *.deb* *.rpm*
./verify.sh  # Test verification script
```

### Using CMake Presets (Recommended)
```bash
# 1. Set environment variables
export GPG_SIGNING_KEY="maintainer@example.com"
export GPG_PASSPHRASE_FILE="$HOME/.gpg_passphrase"

# 2. Use the preset workflow
cmake --preset signed-packages
cmake --build --preset signed-packages
cpack --preset signed-packages

# 3. All packages are signed automatically!
```

## Generated Files

After successful signing, you'll have:

**📦 Packages**
- `MySignedLibrary-5.6.0-Linux-Development.tar.gz`
- `MySignedLibrary-5.6.0-Linux-Runtime.tar.gz` 
- `MySignedLibrary-5.6.0-Linux-Tools.tar.gz`
- `mysignedlibrary-development_5.6.0_amd64.deb`
- `mysignedlibrary-runtime_5.6.0_amd64.deb`
- `mysignedlibrary-tools_5.6.0_amd64.deb`
- `mysignedlibrary-Development-5.6.0-1.x86_64.rpm`
- `mysignedlibrary-Runtime-5.6.0-1.x86_64.rpm` 
- `mysignedlibrary-Tools-5.6.0-1.x86_64.rpm`

**🔐 Signatures**  
- `*.sig` - GPG detached signatures for each package

**📊 Checksums**
- `*.sha256`
- `*.sha512`

**✅ Verification**
- `verify.sh` - Automated verification script for consumers

## Prerequisites

**Required:**
- GPG installed (`gpg2` or `gpg`)
- Valid GPG signing key in keyring

**Optional:**
- Passphrase file for automated signing (if key has passphrase)
- GPG agent configured for passphrase caching
- Keyserver access for public key distribution

## CMake Presets Integration

The signing workflow integrates with CMake presets for streamlined CI/CD:

```json
{
  "configurePresets": [
    {
      "name": "signed-packages",
      "binaryDir": "${sourceDir}/build-signed", 
      "cacheVariables": {
        "GPG_SIGNING_KEY": {
          "type": "STRING",
          "value": "$env{GPG_SIGNING_KEY}"
        },
        "GPG_PASSPHRASE_FILE": {
          "type": "STRING", 
          "value": "$env{GPG_PASSPHRASE_FILE}"
        }
      }
    }
  ],
  "packagePresets": [
    {
      "name": "signed-packages",
      "configurePreset": "signed-packages",
      "generators": ["TGZ", "DEB", "RPM"],
      "packageDirectory": "${sourceDir}/build-signed/packages"
    }
  ]
}
```

## Verification Example

Consumers can verify packages using the generated script:

```bash
# Download packages and signatures
wget https://releases.example.com/MyLibrary-1.0.0-Linux.tar.gz
wget https://releases.example.com/MyLibrary-1.0.0-Linux.tar.gz.sig
wget https://releases.example.com/verify.sh

# Run verification
chmod +x verify.sh
./verify.sh

# Output:
# ✓ MyLibrary-1.0.0-Linux.tar.gz verified successfully
# ✓ SHA256 checksum verified
# ✓ GPG signature verified
```

## Status: Experimental

- ✅ Signs all CPack package formats automatically
- ✅ Generates cryptographic checksums and signatures
- ✅ Creates consumer verification workflows
- ✅ Integrates with CI/CD via presets and environment variables
- ✅ Maintains backward compatibility
- ? Cross-platform support (Linux, macOS, Windows)