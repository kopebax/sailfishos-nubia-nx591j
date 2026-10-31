# miniafservice (audioflingerglue) for nx591j, packaged from the Android tree.
#
# droid-hal drops these files expecting the gg stage to package them, but gg skips
# audioflingerglue when pulseaudio-modules-droid-hidl is in the patterns, and its spec
# would take the 64-bit library although miniafservice is 32-bit. CameraService (and so
# the camera and video playback) waits for media.audio_flinger without it.
# Build: build_packages.sh --build=hybris/droid-miniaf-nx591j --spec=rpm/droid-miniaf-nx591j.spec
%define __requires_exclude ^.*$
%define __provides_exclude_from ^.*$
%global debug_package %{nil}
%define strip /bin/true
%define out %(echo ${ANDROID_ROOT:-$HOME/hadk})/out/target/product/nx591j/system

Name:       droid-miniaf-nx591j
Version:    1.0
Release:    1
Summary:    audioflingerglue miniafservice for nx591j (Android 7, 32-bit)
License:    Apache-2.0

%description
%{summary}.

%install
install -D -m 755 %{out}/bin/miniafservice %{buildroot}%{_libexecdir}/droid-hybris/system/bin/miniafservice
install -D -m 644 %{out}/lib/libaudioflingerglue.so %{buildroot}%{_libexecdir}/droid-hybris/system/lib/libaudioflingerglue.so
install -D -m 644 %{out}/lib64/libaudioflingerglue.so %{buildroot}%{_libexecdir}/droid-hybris/system/lib64/libaudioflingerglue.so

%files
%{_libexecdir}/droid-hybris/system/bin/miniafservice
%{_libexecdir}/droid-hybris/system/lib/libaudioflingerglue.so
%{_libexecdir}/droid-hybris/system/lib64/libaudioflingerglue.so
