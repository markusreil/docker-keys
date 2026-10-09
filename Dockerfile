ARG ALPINE_VERSION=3.21
FROM alpine:${ALPINE_VERSION} AS builder
ARG AGE_PLUGIN_YUBIKEY_VERSION=0.5.0
RUN apk add --no-cache cargo rust pcsc-lite-dev musl-dev openssl-dev \
    && cargo install --locked --root /out --version ${AGE_PLUGIN_YUBIKEY_VERSION} age-plugin-yubikey \
    && /out/bin/age-plugin-yubikey --version

FROM alpine:${ALPINE_VERSION}

LABEL maintainer="docker-keys" \
      description="All-in-one key management image: ssh, pgp, age, paperkey, qr codes, yubikey"

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk add --no-cache \
      bash \
      openssh-client \
      gnupg \
      gnupg-scdaemon \
      pcsc-lite-libs \
      ccid \
      libusb \
      paperkey@testing \
      age \
      openssl \
      libqrencode-tools \
      zbar \
      imagemagick \
      yubico-piv-tool \
      opensc \
      yubikey-manager \
      ykpers \
      jq \
      git \
      pinentry \
    && rm -rf /var/cache/apk/*

COPY --from=builder /out/bin/age-plugin-yubikey /usr/local/bin/age-plugin-yubikey

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /work
VOLUME ["/root/.gnupg", "/root/.ssh"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
