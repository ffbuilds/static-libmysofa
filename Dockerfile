
# bump: libmysofa /LIBMYSOFA_VERSION=([\d.]+)/ https://github.com/hoene/libmysofa.git|^1
# bump: libmysofa after ./hashupdate Dockerfile LIBMYSOFA $LATEST
# bump: libmysofa link "Release" https://github.com/hoene/libmysofa/releases/tag/$LATEST
# bump: libmysofa link "Source diff $CURRENT..$LATEST" https://github.com/hoene/libmysofa/compare/v$CURRENT..v$LATEST
ARG LIBMYSOFA_VERSION=1.3.1
ARG LIBMYSOFA_URL="https://github.com/hoene/libmysofa/archive/refs/tags/v$LIBMYSOFA_VERSION.tar.gz"
ARG LIBMYSOFA_SHA256=a8a8cbf7b0b2508a6932278799b9bf5c63d833d9e7d651aea4622f3bc6b992aa

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBMYSOFA_URL
ARG LIBMYSOFA_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libmysofa.tar.gz "$LIBMYSOFA_URL" && \
  echo "$LIBMYSOFA_SHA256  libmysofa.tar.gz" | sha256sum --status -c - && \
  mkdir libmysofa && \
  tar xf libmysofa.tar.gz -C libmysofa --strip-components=1 && \
  rm libmysofa.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libmysofa/ /tmp/libmysofa/
WORKDIR /tmp/libmysofa/build
RUN \
  apk add --no-cache --virtual build \
    build-base cmake pkgconf zlib-dev zlib-static && \
  cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=OFF \
    .. && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path libmysofa && \
  ar -t /usr/local/lib/libmysofa.a && \
  readelf -h /usr/local/lib/libmysofa.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBMYSOFA_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libmysofa.pc /usr/local/lib/pkgconfig/libmysofa.pc
COPY --from=build /usr/local/lib/libmysofa.a /usr/local/lib/libmysofa.a
COPY --from=build /usr/local/include/mysofa.h /usr/local/include/mysofa.h
