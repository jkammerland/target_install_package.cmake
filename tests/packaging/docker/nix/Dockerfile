FROM nixos/nix:latest

# Install additional dependencies
RUN nix-env -iA \
    nixpkgs.cmake \
    nixpkgs.gcc \
    nixpkgs.git \
    nixpkgs.bash

# Set working directory
WORKDIR /test

# Copy test script
COPY test.sh /test/test.sh
RUN chmod +x /test/test.sh

# Entry point - use bash explicitly since it's not at /bin/bash in Nix
ENTRYPOINT ["bash", "/test/test.sh"]