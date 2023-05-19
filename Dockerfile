ARG tool_version="foobar"

FROM alpine

LABEL MAINTAINER="David Schunke"

ARG tool_version
ENV TOOL_VERSION=$tool_version

RUN apk --no-cache upgrade
RUN apk --no-cache add \
	automake autoconf libtool make icu fuse libuuid libxml2 net-snmp libc-dev \
	mbuffer mt-st lsscsi bash tar

COPY lto_manager.sh /root/
RUN chmod +x /root/lto_manager.sh

COPY ITDT /root/ITDT/
RUN chmod +x /root/ITDT/itdt

ENTRYPOINT ["/root/lto_manager.sh"]
