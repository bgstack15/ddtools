# ref: http://www.rpm.org/max-rpm/s1-rpm-build-creating-spec-file.html
Summary:	suite of scripts for managing dns and dhcpd
Name:		ddtools
Version:	0.0
Release:	3
License:	CC BY-SA 4.0
Group:		Applications/System
Source:		ddtools.tgz
URL:		https://bgstack15.wordpress.com/
#Distribution:
#Vendor:
Packager:	B Stack <bgstack15@gmail.com>
Requires:	bgscripts-core >= 1.2-11
Obsoletes:	updatezone <= %{version}-%{release}
Buildarch:	noarch

%description
ddtools provides shell scripts that help manage dns and dhcpd.
updatezone.sh takes a simple config file for selecting the dns zone files to edit. Bind is the only supported dns server right now, but experimentation is encouraged.
dhcpd-control helps manage paired dhcpd servers.

#%global _python_bytecompile_errors_terminate_build 0

%prep
%setup

%build

%install
rm -rf %{buildroot}
rsync -a . %{buildroot}/ --exclude='**/.*.swp' --exclude='**/.git'

%post
exit 0

%preun
exit 0

%postun
exit 0

%files

%changelog
* Sat Oct 14 2017 B Stack <bgstack15@gmail.com> 0.0-3
- Updated content. See doc/README.txt

* Sat May 27 2017 B Stack <bgstack15@gmail.com> 0.0-1
- Initial rpm release
