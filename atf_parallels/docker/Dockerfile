ARG ubuntu_ver

FROM ubuntu:${ubuntu_ver}

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get -q -y install \
  locales sudo libssl1.0.0 libusb-1.0-0 libbluetooth3 openssl liblua5.2-0 psmisc \
  libexpat1 sqlite3 libqt5websockets5 net-tools iproute2 \
  libssl-doc- libusb-1.0-doc- autotools-dev- binutils- build-essential- bzip2- cpp- cpp-5- \
  dpkg-dev- fakeroot- manpages- manpages-dev- qttranslations5-l10n- xdg-user-dirs- xml-core- dbus-

RUN ln -s /lib/x86_64-linux-gnu/libexpat.so.1.6.7 /usr/lib/x86_64-linux-gnu/libexpat.so

RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8

RUN chmod u+s /sbin/ifconfig /sbin/ip && mkdir /home/developer

COPY entrypoint.sh /usr/bin/

ENTRYPOINT ["/bin/bash", "-e", "/usr/bin/entrypoint.sh"]
