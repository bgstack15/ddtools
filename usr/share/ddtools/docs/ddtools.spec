# ref: http://www.rpm.org/max-rpm/s1-rpm-build-creating-spec-file.html
Summary:	suite of scripts for managing dns and dhcpd
Name:		ddtools
Version:	0.0
Release:	2
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
%dir /etc/updatezone
%dir /usr/share/updatezone
%dir /usr/share/updatezone/inc
%dir /usr/share/updatezone/examples
%dir /usr/share/updatezone/docs
/usr/share/updatezone/inc/pack
/usr/share/updatezone/inc/get-files
%config %attr(666, -, -) /usr/share/updatezone/examples/ipa.smith122.com.conf.example
%doc %attr(444, -, -) /usr/share/updatezone/docs/files-for-versioning.txt
%doc %attr(444, -, -) /usr/share/updatezone/docs/packaging.txt
%doc %attr(444, -, -) /usr/share/updatezone/docs/README.txt
/usr/share/updatezone/docs/updatezone.spec
/usr/share/updatezone/updatezone.sh
%verify(link) /usr/bin/updatezone

%changelog
* Sat May 27 2017 B Stack <bgstack15@gmail.com> 0.0-1
- Initial rpm release
