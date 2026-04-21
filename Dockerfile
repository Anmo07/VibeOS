FROM fedora:39
RUN dnf update -y && \
    dnf install -y livecd-tools lorax xorriso squashfs-tools dosfstools mtools \
        dnf-plugins-core cpio anaconda hfsplus-tools pykickstart isomd5sum && \
    if [ $(uname -m) = "x86_64" ]; then dnf install -y syslinux syslinux-nonlinux; fi && \
    dnf clean all
WORKDIR /workspace
RUN dnf install -y git && \
    git clone --branch f39 https://pagure.io/fedora-kickstarts.git /usr/share/spin-kickstarts
CMD ["/bin/bash"]
