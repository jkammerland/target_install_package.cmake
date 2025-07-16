FROM fedora:42

# Install dependencies
RUN dnf install -y \
    cmake \
    gcc-c++ \
    make \
    git \
    rpm-build \
    && dnf clean all

# Set working directory
WORKDIR /test

# # Copy test script
COPY test.sh /test/test.sh
RUN chmod +x /test/test.sh

# Entry point
ENTRYPOINT ["/test/test.sh"]