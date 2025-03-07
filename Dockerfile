FROM golang:1.24.0-bookworm AS patcher-builder

COPY patcher patcher
RUN go build -C patcher

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND="noninteractive"

RUN useradd -m steam && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y wget software-properties-common && \
    add-apt-repository multiverse && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update -y && \
    apt-get install -y --install-recommends winehq-stable && \
    apt-get install -y gdebi-core libgl1-mesa-glx:i386 steam steamcmd winbind xvfb cabextract && \
    apt-get remove -y --purge wget software-properties-common && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSfLO https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x winetricks && \
    mv -v winetricks /usr/local/bin

RUN winecfg && \
    sleep 5 && \
    xvfb-run winetricks -q vcrun2022

RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

VOLUME /server /root/Steam

COPY --from=patcher-builder /go/patcher/patcher /usr/local/bin/patcher
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chmod +x /usr/local/bin/patcher
CMD ["/entrypoint.sh"]
