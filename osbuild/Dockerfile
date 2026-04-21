# OSBuild Builder — Fedora Image Builder container
# Used as an alternative backend to livecd-creator
FROM fedora:39

RUN dnf install -y \
    osbuild \
    osbuild-composer \
    composer-cli \
    bash \
    && dnf clean all

# Enable the osbuild-composer socket (activated on demand)
RUN systemctl enable osbuild-composer.socket 2>/dev/null || true

WORKDIR /workspace
CMD ["/bin/bash"]
