FROM archlinux:latest

# Update system and install dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    cmake \
    git \
    sudo

# Create build user (makepkg won't run as root)
RUN useradd -m builder && \
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