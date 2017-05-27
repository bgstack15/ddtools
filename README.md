### Overview
updatezone is a tool that helps you easily adjust dns zone files. It handles incrementing the serial number and pushing updates to slave dns servers. For the complete documentation of the package itself, view usr/share/updatezone/docs/README.txt.

### Building
The recommended way to build an rpm is:

    pushd ~/rpmbuild; mkdir -p SOURCES RPMS SPECS BUILD BUILDROOT; popd
    mkdir -p ~/rpmbuild/SOURCES/updatezone-0.0-1
    cd ~/rpmbuild/SOURCES/updatezone-0.0-1
    git clone https://github.com/bgstack15/updatezone
    usr/share/updatezone/inc/pack rpm

The generated rpm will be in ~/rpmbuild/RPMS/noarch
