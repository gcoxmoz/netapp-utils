# $Id$
%define debug_package %{nil}
%define perl_vendorlib /usr/lib64/perl5/vendor_perl

Summary:   NetApp's SDK for interacting with filers
Name:      NetApp-SDK
Version:   9.7
Release:   1%{?dist}
License:   NetApp SDK License Agreement v11-04-14
Group:     Development/Libraries
Source:    https://mysupport.netapp.com/api/sw-download-service/productdownloads/63095/download/netapp-manageability-sdk-%{version}.zip
Patch0:    %{name}-%{version}-perlfix-OCUMAPI.patch
Patch1:    %{name}-%{version}-perlfix-OntapClusterAPI.patch
URL:       http://support.netapp.com
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Vendor:    Mozilla IT

%description
Empty placeholder


%package Perl
Summary:   A Perl SDK for interacting with NetApp filers
BuildArch: noarch
Prefix: %{perl_vendorlib}

%description Perl
The NetApp Manageability SDK provides resources to develop applications that monitor and manage NetApp storage systems.

%prep
%setup -q -n netapp-manageability-sdk-%{version}
%patch0 -p0
%patch1 -p0

%build

%install
%{__mkdir} -p $RPM_BUILD_ROOT%{perl_vendorlib}/%{name}
%{__cp} lib/perl/NetApp/NaServer.pm $RPM_BUILD_ROOT%{perl_vendorlib}/%{name}
%{__cp} lib/perl/NetApp/NaElement.pm $RPM_BUILD_ROOT%{perl_vendorlib}/%{name}
%{__cp} lib/perl/NetApp/OCUMAPI.pm $RPM_BUILD_ROOT%{perl_vendorlib}/%{name}
%{__cp} lib/perl/NetApp/OntapClusterAPI.pm $RPM_BUILD_ROOT%{perl_vendorlib}/%{name}
# You could add more files here, maybe even wildcard it.  But I like a tidy directory.

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files Perl
%defattr(-,root,root,-)
%{perl_vendorlib}/%{name}/*

%changelog
* Mon Apr 29 2020 Greg Cox <gcox@mozilla.com> 9.7
- SDK 9.7

* Mon Dec 31 2018 Greg Cox <gcox@mozilla.com> 9.5
- SDK 9.5

* Fri Feb  2 2018 Greg Cox <gcox@mozilla.com> 9.3
- SDK 9.3

* Tue Sep 26 2017 Greg Cox <gcox@mozilla.com> 5.7
- SDK 5.7

* Tue Dec 20 2016 Greg Cox <gcox@mozilla.com> 5.6
- SDK 5.6

* Wed May 4 2016 Greg Cox <gcox@mozilla.com> 5.4P2
- SDK 5.4P2

