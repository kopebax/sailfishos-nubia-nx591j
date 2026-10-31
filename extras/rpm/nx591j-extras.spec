Name:       nx591j-extras
Version:    1.2
Release:    1
Summary:    Nubia Z17 Lite (nx591j) runtime fixes for Sailfish OS
License:    BSD-3-Clause
URL:        https://github.com/kopebax/sailfishos-nubia-nx591j
Source0:    %{name}-%{version}.tar.gz
BuildRequires: gcc
Requires:   python3-base
Requires:   dbus
Requires:   ngfd-plugin-native-vibrator

%description
Device specific runtime fixes for the nx591j Sailfish OS port:
 * libtlspad + /etc/ld.so.preload: reserves the start of the glibc static TLS block,
   which Android 7 bionic code (EGL, Adreno) writes its TLS slots into on aarch64.
   Without it lipstick and every Qt app crash once the Android graphics stack loads.
 * nubia-keyhaptic: haptic feedback for the capacitive keys below the screen.
 * longer ngfd haptic effects: the default 5-30 ms pulses are too short for this motor.
 * nubia-bt-attach: brings up the WCNSS Bluetooth core (hci_smd) with the BD address
   stored in /persist.
 * nubia-bt-a2dp-fix: switches speakers that also offer an A2DP source role to the
   a2dp-sink profile.
 * nubia-callaudio: voice call audio routing (earpiece/speaker/mute) for
   nubia-audiobridge.
 * libnovao + Pure Maps launcher: MapLibre crashes the Adreno 510 driver with VAOs.

%prep
%autosetup -n %{name}-%{version}

%build
gcc %{optflags} -O2 -shared -fPIC -ftls-model=initial-exec -o libtlspad.so src/tlspad.c
gcc %{optflags} -O2 -shared -fPIC -o libnovao.so src/novao.c -ldl

%install
install -D -m 755 libtlspad.so %{buildroot}%{_libdir}/libtlspad.so
install -d %{buildroot}%{_sysconfdir}
echo %{_libdir}/libtlspad.so > %{buildroot}%{_sysconfdir}/ld.so.preload
install -D -m 755 libnovao.so %{buildroot}%{_libdir}/libnovao.so

install -d %{buildroot}%{_libexecdir}/nubia %{buildroot}%{_unitdir}/multi-user.target.wants
for s in nubia-keyhaptic nubia-bt-attach nubia-bt-a2dp-fix nubia-callaudio; do
    install -m 755 files/$s.py %{buildroot}%{_libexecdir}/nubia/$s.py
    sed "s|/usr/local/bin/$s.py|%{_libexecdir}/nubia/$s.py|" files/$s.service \
        | install -D -m 644 /dev/stdin %{buildroot}%{_unitdir}/$s.service
done
for s in nubia-keyhaptic nubia-bt-attach nubia-callaudio; do
    ln -s ../$s.service %{buildroot}%{_unitdir}/multi-user.target.wants/$s.service
done
install -d %{buildroot}%{_unitdir}/bluetooth.service.wants
ln -s ../nubia-bt-a2dp-fix.service %{buildroot}%{_unitdir}/bluetooth.service.wants/nubia-bt-a2dp-fix.service

install -D -m 644 files/60-droid-vibrator-nx591j.ini %{buildroot}%{_datadir}/ngfd/plugins.d/60-droid-vibrator-nx591j.ini
install -m 755 files/harbour-pure-maps-hybris %{buildroot}%{_libexecdir}/nubia/harbour-pure-maps-hybris

# Pure Maps comes from Chum and is updated from there: point its launcher at the wrapper
# every time it is installed or updated.
%triggerin -- harbour-pure-maps
f=%{_datadir}/applications/harbour-pure-maps.desktop
if [ -f $f ]; then
    sed -i -e 's|^Exec=.*harbour-pure-maps$|Exec=%{_libexecdir}/nubia/harbour-pure-maps-hybris|' \
           -e 's|^X-Nemo-Application-Type=.*|X-Nemo-Application-Type=no-invoker|' $f
fi

%files
%{_libdir}/libtlspad.so
%config %{_sysconfdir}/ld.so.preload
%{_libdir}/libnovao.so
%dir %{_libexecdir}/nubia
%{_libexecdir}/nubia/nubia-keyhaptic.py
%{_libexecdir}/nubia/nubia-bt-attach.py
%{_libexecdir}/nubia/nubia-bt-a2dp-fix.py
%{_libexecdir}/nubia/nubia-callaudio.py
%{_libexecdir}/nubia/harbour-pure-maps-hybris
%{_unitdir}/nubia-keyhaptic.service
%{_unitdir}/nubia-bt-attach.service
%{_unitdir}/nubia-bt-a2dp-fix.service
%{_unitdir}/nubia-callaudio.service
%{_unitdir}/multi-user.target.wants/nubia-keyhaptic.service
%{_unitdir}/multi-user.target.wants/nubia-bt-attach.service
%{_unitdir}/multi-user.target.wants/nubia-callaudio.service
%{_unitdir}/bluetooth.service.wants/nubia-bt-a2dp-fix.service
%{_datadir}/ngfd/plugins.d/60-droid-vibrator-nx591j.ini
