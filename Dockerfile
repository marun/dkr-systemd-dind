#
# Container running systemd and docker-in-docker.  Useful for
# simulating multinode deployments of [container orchestration
# system].
#
# The standard name for this image is maru/systemd-dind
#
# Notes:
#
#  - disable SELinux on the docker host (not compatible with dind)
#
#  - to use the overlay graphdriver, ensure the overlay module is
#    installed on the docker host
#
#      $ modprobe overlay
#
#  - run with --privileged
#
#      $ docker run -d --privileged maru/systemd-dind
#

FROM fedora:28
MAINTAINER marun@redhat.com

# Fix 'WARNING: terminal is not fully functional' when TERM=dumb
ENV TERM=xterm

## Configure systemd to run in a container

ENV container=docker

VOLUME ["/run", "/tmp"]

STOPSIGNAL SIGRTMIN+3

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

RUN systemctl mask\
 auditd.service\
 console-getty.service\
 dev-hugepages.mount\
 dnf-makecache.service\
 docker-storage-setup.service\
 getty.target\
 lvm2-lvmetad.service\
 sys-fs-fuse-connections.mount\
 systemd-logind.service\
 systemd-remount-fs.service\
 systemd-udev-hwdb-update.service\
 systemd-udev-trigger.service\
 systemd-udevd.service\
 systemd-vconsole-setup.service
RUN cp /usr/lib/systemd/system/dbus.service /etc/systemd/system/;\
 sed -i 's/OOMScoreAdjust=-900//' /etc/systemd/system/dbus.service

# Remove non-english translations for glibc to reduce image size by 100mb.
RUN dnf -y update && dnf -y install\
 docker\
 glibc-langpack-en\
 iptables\
 && dnf -y remove\
 glibc-all-langpacks\
 && dnf clean all

## Configure docker

RUN systemctl enable docker.service

# Default storage to vfs.  overlay will be enabled at runtime if available.
RUN echo "DOCKER_STORAGE_OPTIONS=--storage-driver vfs" >\
 /etc/sysconfig/docker-storage

COPY dind-setup.sh /usr/local/bin
COPY dind-setup.service /etc/systemd/system/
RUN systemctl enable dind-setup.service

VOLUME ["/var/lib/docker"]

# Hardlink init to another name to avoid having oci-systemd-hooks
# detect containers using this image as requiring read-only cgroup
# mounts.  containers running docker need to be run with --privileged
# to ensure cgroups are mounted with read-write permissions.
RUN ln /usr/sbin/init /usr/sbin/dind_init

CMD ["/usr/sbin/dind_init"]
