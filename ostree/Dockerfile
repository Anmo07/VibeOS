# OSTree Builder — rpm-ostree compose environment
FROM fedora:39

RUN dnf install -y \
    rpm-ostree \
    ostree \
    lorax \
    createrepo_c \
    python3 \
    bash \
    && dnf clean all

WORKDIR /workspace
CMD ["/bin/bash"]
