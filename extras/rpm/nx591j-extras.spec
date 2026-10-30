Name:       nx591j-extras
Version:    1.0
Release:    1
Summary:    Nubia Z17 Lite (nx591j) runtime fixes for Sailfish OS
License:    BSD-3-Clause
URL:        https://github.com/kopebax/sailfishos-nubia-nx591j
Source0:    %{name}-%{version}.tar.gz
BuildRequires: gcc
Requires:   python3-base
Requires:   ngfd-plugin-native-vibrator

%description
Device specific runtime fixes for the nx591j Sailfish OS port:
 * libtlspad + /etc/ld.so.preload: reserves the start of the glibc static TLS block,
   which Android 7 bionic code (EGL, Adreno) writes its TLS slots into on aarch64.
   Without it lipstick and every Qt app crash once the Android graphics stack loads.
 * nubia-keyhaptic: haptic feedback for the capacitive keys below the screen.
 * longer ngfd haptic effects: the default 5-30 ms pulses are too short for this motor.

%prep
%autosetup -n %{name}-%{version}

%build
gcc %{optflags} -O2 -shared -fPIC -ftls-model=initial-exec -o libtlspad.so src/tlspad.c

%install
install -D -m 755 libtlspad.so %{buildroot}%{_libdir}/libtlspad.so
install -d %{buildroot}%{_sysconfdir}
echo %{_libdir}/libtlspad.so > %{buildroot}%{_sysconfdir}/ld.so.preload
install -D -m 755 files/nubia-keyhaptic.py %{buildroot}%{_libexecdir}/nubia/nubia-keyhaptic.py
sed 's|/usr/local/bin/nubia-keyhaptic.py|%{_libexecdir}/nubia/nubia-keyhaptic.py|' files/nubia-keyhaptic.service \
    | install -D -m 644 /dev/stdin %{buildroot}%{_unitdir}/nubia-keyhaptic.service
install -d %{buildroot}%{_unitdir}/multi-user.target.wants
ln -s ../nubia-keyhaptic.service %{buildroot}%{_unitdir}/multi-user.target.wants/nubia-keyhaptic.service
install -D -m 644 files/60-droid-vibrator-nx591j.ini %{buildroot}%{_datadir}/ngfd/plugins.d/60-droid-vibrator-nx591j.ini

%files
%{_libdir}/libtlspad.so
%config %{_sysconfdir}/ld.so.preload
%{_libexecdir}/nubia/nubia-keyhaptic.py
%{_unitdir}/nubia-keyhaptic.service
%{_unitdir}/multi-user.target.wants/nubia-keyhaptic.service
%{_datadir}/ngfd/plugins.d/60-droid-vibrator-nx591j.ini
