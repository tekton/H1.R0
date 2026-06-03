# ================================
# Build image
# ================================
FROM swift:5.9-jammy as build

# Native build dependencies for SwiftGD (libgd) and image codecs.
RUN apt-get update && apt-get install -y \
    libgd-dev \
    libjpeg-turbo8-dev \
    libpng-dev \
    libexif-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Resolve dependencies first for better layer caching.
COPY ./Package.* ./
RUN swift package resolve

# Copy the entire project and build a release binary.
COPY . .
RUN swift build -c release --static-swift-stdlib

# Stage the run-time artifacts into /staging.
WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true
# Ship the Rails-era image assets so they can be served and processed.
RUN mkdir -p ./app/assets && cp -R /build/app/assets/images ./app/assets/images

# ================================
# Run image
# ================================
FROM swift:5.9-jammy-slim

# Native run-time dependencies:
#   libgd3 / libjpeg / libpng  -> SwiftGD image processing
#   libexif12                  -> EXIF support libs
#   libimage-exiftool-perl     -> the `exiftool` binary used by ExifService
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get update && apt-get install -y \
       ca-certificates \
       tzdata \
       libgd3 \
       libjpeg-turbo8 \
       libpng16-16 \
       libexif12 \
       libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# Create an unprivileged user to run the app.
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor

EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
