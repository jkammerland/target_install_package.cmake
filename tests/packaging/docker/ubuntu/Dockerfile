FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /test

# Copy test script
COPY test.sh /test/test.sh
RUN chmod +x /test/test.sh

# Entry point
ENTRYPOINT ["/test/test.sh"]