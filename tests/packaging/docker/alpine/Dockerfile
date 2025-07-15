FROM alpine:3.18

# Install dependencies
RUN apk add --no-cache \
    cmake \
    make \
    g++ \
    git \
    bash \
    alpine-sdk \
    sudo

# Create build user (required for abuild)
RUN adduser -D builder && \
    addgroup builder abuild && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set working directory
WORKDIR /test

# Copy test script
COPY test.sh /test/test.sh
RUN chmod +x /test/test.sh

# Switch to builder user for package building
USER builder

# Entry point
ENTRYPOINT ["/test/test.sh"]