FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    WINEPREFIX=/opt/wineprefix \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY=:99

# Official embeddable Python 3.11 zip: a plain archive, no installer needed.
ARG PY_WIN_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip

RUN apt-get update && apt-get install -y --no-install-recommends \
        wine wine64 xvfb xauth wget ca-certificates cabextract python3 procps \
        x11-utils xdotool unzip \
    && rm -rf /var/lib/apt/lists/* \
    && for t in wine wineserver Xvfb python3 wget ps find xwininfo xdotool unzip; do \
         command -v "$t" >/dev/null || { echo "MISSING TOOL: $t"; exit 1; }; \
       done

RUN wget -q -O /opt/python-embed.zip "$PY_WIN_URL"

# The link to the MT5 terminal zip, kept in the repo (private repo only).
COPY mt5_url.txt /opt/mt5_url.txt
COPY scripts/build_wine.sh /opt/build_wine.sh
RUN bash /opt/build_wine.sh && rm -f /opt/python-embed.zip

COPY scripts/ /opt/spike/
RUN chmod +x /opt/spike/*.sh /opt/build_wine.sh

CMD ["/opt/spike/start.sh"]
