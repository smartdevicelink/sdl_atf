ARG ubuntu_ver

FROM ubuntu:${ubuntu_ver}

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

ARG openssl_lib_ver

RUN apt-get update && apt-get -q -y install \
  locales sudo libssl${openssl_lib_ver} libssl-dev libusb-1.0-0 libbluetooth3 openssl liblua5.2-0 psmisc \
  libexpat1 sqlite3 libqt5websockets5 net-tools iproute2 \
  libssl-doc- libusb-1.0-doc- autotools-dev- binutils- build-essential- bzip2- cpp- \
  dpkg-dev- fakeroot- manpages- manpages-dev- qttranslations5-l10n- xdg-user-dirs- xml-core- dbus-

ARG expat_lib_ver

RUN ln -s /lib/x86_64-linux-gnu/libexpat.so.${expat_lib_ver} /usr/lib/x86_64-linux-gnu/libexpat.so

RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8

RUN chmod u+s /sbin/ifconfig /sbin/ip && mkdir /home/developer

COPY entrypoint.sh /usr/bin/

ENTRYPOINT ["/bin/bash", "-e", "/usr/bin/entrypoint.sh"]
