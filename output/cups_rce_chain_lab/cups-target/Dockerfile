FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Build dependencies ────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget curl git ca-certificates \
        build-essential autoconf automake libtool pkg-config \
        libavahi-client-dev libavahi-common-dev \
        libgnutls28-dev libssl-dev \
        libdbus-1-dev \
        libsystemd-dev \
        zlib1g-dev \
        libusb-1.0-0-dev \
        libpam0g-dev \
        libpng-dev libjpeg-dev libtiff-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        fonts-freefont-ttf \
        poppler-utils \
        ghostscript \
        libqpdf-dev \
        libcupsimage2-dev \
        cups \
        cups-client \
        avahi-daemon \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ── 1. libcupsfilters 2.1b1 (CVE-2024-47076) ─────────────────────────────
RUN wget -q https://github.com/OpenPrinting/libcupsfilters/releases/download/2.1b1/libcupsfilters-2.1b1.tar.gz \
    && tar xzf libcupsfilters-2.1b1.tar.gz \
    && cd libcupsfilters-2.1b1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf libcupsfilters-2.1b1*

# ── 2. libppd 2.1b1 (CVE-2024-47175) ─────────────────────────────────────
RUN wget -q https://github.com/OpenPrinting/libppd/releases/download/2.1b1/libppd-2.1b1.tar.gz \
    && tar xzf libppd-2.1b1.tar.gz \
    && cd libppd-2.1b1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf libppd-2.1b1*

# ── 3. cups-filters 2.0.1 (CVE-2024-47177 — foomatic-rip command injection) ──
RUN wget -q https://github.com/OpenPrinting/cups-filters/releases/download/2.0.1/cups-filters-2.0.1.tar.gz \
    && tar xzf cups-filters-2.0.1.tar.gz \
    && cd cups-filters-2.0.1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf cups-filters-2.0.1*

# ── 4. cups-browsed 2.0.1 (CVE-2024-47176) ───────────────────────────────
RUN wget -q https://github.com/OpenPrinting/cups-browsed/releases/download/2.0.1/cups-browsed-2.0.1.tar.gz \
    && tar xzf cups-browsed-2.0.1.tar.gz \
    && cd cups-browsed-2.0.1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && cd /build && rm -rf cups-browsed-2.0.1*

# ── CUPS configuration ────────────────────────────────────────────────────
COPY cups/cupsd.conf        /etc/cups/cupsd.conf
COPY cups/cups-browsed.conf /etc/cups/cups-browsed.conf

# ── Flag ──────────────────────────────────────────────────────────────────
RUN echo "FLAG{cups_rce_chain_pwned_CVE-2024-47076_47175_47176_47177}" > /root/flag.txt \
    && chmod 600 /root/flag.txt

# ── Entrypoint ────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 631/udp 631/tcp 8080/tcp

ENTRYPOINT ["/entrypoint.sh"]
