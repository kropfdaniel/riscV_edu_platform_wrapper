FROM debian:bookworm-slim

# Install fish and curl (needed to download the suite)
RUN apt-get update && apt-get install -y --no-install-recommends \
    fish \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and extract the OSS CAD Suite
RUN curl -L https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-10-11/oss-cad-suite-linux-x64-20261011.tgz | tar -xz -C /opt

# Add the OSS CAD Suite binaries to the system PATH
ENV PATH="/opt/oss-cad-suite/bin:$PATH"

# Copy the generic script from your repo into the container's path
COPY check_equiv.fish /usr/local/bin/check_equiv
RUN chmod +x /usr/local/bin/check_equiv

WORKDIR /workspace

ENTRYPOINT ["fish"]