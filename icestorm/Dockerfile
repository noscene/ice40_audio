# icestorm Installation
FROM ubuntu:trusty
MAINTAINER Sven Braun <s.braun@mobileonly.com>
#EXPOSE 80 3306
RUN sudo apt-get update  && apt-get -y install  build-essential clang bison flex libreadline-dev gawk tcl-dev libffi-dev git mercurial graphviz xdot pkg-config python python3 libftdi-dev php5-cli curl && cd /root  && git clone https://github.com/cliffordwolf/icestorm.git icestorm && cd icestorm && make -j$(nproc) && make install && cd /root && git clone https://github.com/cseed/arachne-pnr.git arachne-pnr && cd arachne-pnr && make -j$(nproc) && make install  && cd /root && git clone https://github.com/cliffordwolf/yosys.git yosys && cd yosys && make -j$(nproc) && make install && \ 
cd /root && git clone https://github.com/cliffordwolf/icotools.git icotools && cd icotools && cd /root

#CMD  /etc/init.d/mysql start && apachectl -DFOREGROUND

