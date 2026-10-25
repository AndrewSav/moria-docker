FROM golang:1.27.3-trixie AS tools-builder

COPY patcher patcher
RUN go build -C patcher
COPY healthcheck healthcheck
RUN go build -C healthcheck

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND="noninteractive"

RUN userdel ubuntu && useradd -m -u 1000 steam && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends steamcmd wine-stable-amd64 && \
    cd /tmp && \
    apt-get download wine-stable=$(dpkg-query -Wf '${Version}' wine-stable-amd64) winehq-stable=$(dpkg-query -Wf '${Version}' wine-stable-amd64) && \
    dpkg-deb -x wine-stable_*.deb / && dpkg-deb -x winehq-stable_*.deb / && \
    mkdir /wineprefix-template && chown steam:steam /wineprefix-template && \
    runuser -l steam -c "export WINEPREFIX=/wineprefix-template; wineboot --init && wineserver -w" && \
    test -s /wineprefix-template/system.reg && test -s /wineprefix-template/user.reg && \
    find /wineprefix-template -type f | while read -r f; do \
        for d in /opt/wine-stable/lib/wine/x86_64-windows /opt/wine-stable/share/wine/nls /opt/wine-stable/share/wine; do \
            t="$d/$(basename "$f")"; \
            if [ -f "$t" ] && cmp -s "$f" "$t"; then ln -f "$t" "$f"; break; fi; \
        done; \
    done && \
    apt-get remove -y --purge wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /home/steam/.cache

RUN date -u +%Y%m%dT%H%M%SZ > /wineprefix-template/.timestamp

RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

VOLUME /server
VOLUME /wineprefix-volume

COPY --from=tools-builder /go/patcher/patcher /usr/local/bin/patcher
COPY --from=tools-builder /go/healthcheck/healthcheck /usr/local/bin/healthcheck
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chmod +x /usr/local/bin/patcher && chmod +x /usr/local/bin/healthcheck
HEALTHCHECK --interval=1m --timeout=10s --start-period=5m --start-interval=15s --retries=2 CMD healthcheck localhost:7777
CMD ["/entrypoint.sh"]
