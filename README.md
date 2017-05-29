### Overview
ddtools is a collection of tools for manging dns and dhcpd. For the complete documentation of the package itself, view usr/share/ddtools/docs/README.txt.
updatezone helps you easily adjust dns zone files. It handles incrementing the serial number and pushing updates to slave dns servers. 
dhcpd-control helps manage paired dhcpd servers.

### Building
The recommended way to build an rpm is:

    pushd ~/rpmbuild; mkdir -p SOURCES RPMS SPECS BUILD BUILDROOT; popd
    mkdir -p ~/rpmbuild/SOURCES/ddtools-0.0-2
    cd ~/rpmbuild/SOURCES/ddtools-0.0-2
    git clone https://github.com/bgstack15/ddtools
    usr/share/ddtools/inc/pack rpm

The generated rpm will be in ~/rpmbuild/RPMS/noarch
