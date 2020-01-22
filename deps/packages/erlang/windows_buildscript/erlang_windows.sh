#!/bin/bash
set -ex

echo start build at `date`

thisdir=`pwd`
version=$1
release=$2
release_tag=$3
cb_buildnumber=$4
package_name="${release_tag}-${cb_buildnumber}"
package_name_tgz="erlang-windows_msvc2017-amd64-$package_name.tgz"
package_name_md5="erlang-windows_msvc2017-amd64-$package_name.md5"

# Ensure build uses correct libraries with OpenSSL 1.1.1d
patch_ssl() {
    sed -i "s/SSL_CRYPTO_LIBNAME = @SSL_CRYPTO_LIBNAME@/SSL_CRYPTO_LIBNAME = libcrypto64MD/g" ./lib/crypto/c_src/Makefile.in
    sed -i "s/SSL_SSL_LIBNAME = @SSL_SSL_LIBNAME@/SSL_SSL_LIBNAME = libssl64MD/g" ./lib/crypto/c_src/Makefile.in
}

# Convert dos2unix
find . -type f |xargs dos2unix

installdir="/cygdrive/c/Program Files/erl${version}"
mkdir -p "${installdir}"

## build the source, as per instructions
eval `./otp_build env_win32 x64`
./otp_build autoconf 2>&1 | tee autoconf.out
# Hardcode library names in Makefile template to allow building against OpenSSL 1.1.1d
patch_ssl
./otp_build configure  --with-ssl=/cygdrive/c/OpenSSL 2>&1 | tee configure.out
./otp_build boot -a 2>&1 | tee boot.out
./otp_build release -a 2>&1 | tee release.out
#####./otp_build debuginfo_win32 -a 2>&1 | tee dbginfo.out

## what the "release -a" command generates above in release/win32
## is not ## what is packaged in the installer executable.
## the installer executable also has other files like
## lib, bin -- some of which are partly also in the release/win32
## folder but there are some extra files
## so, generate an installer and use that to install it to default
## location
./otp_build installer_win32 2>&1 | tee installerwin32.out
./release/win32/otp_win64_${release}.exe /S

## we need VERSION.txt, erl.in.ini and CMakeLists.txt for our internal
## cbdeps consumption. We could check the files in with placeholder
## tokens for version. But I am just generating them here dynamically
## because they are tiny files
echo $release_tag > VERSION.txt
echo "[erlang]
Bindir=\${CMAKE_INSTALL_PREFIX}/erts-${version}/bin
Progname=erl
Rootdir=\${CMAKE_INSTALL_PREFIX}
" > erl.ini.in

echo "# Just copy contents to CMAKE_INSTALL_PREFIX
FILE (COPY bin erts-${version} lib releases usr DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")
# And install erl.ini with correct paths
CONFIGURE_FILE(\${CMAKE_CURRENT_SOURCE_DIR}/erl.ini.in \${CMAKE_INSTALL_PREFIX}/bin/erl.ini)
" > CMakeLists.txt

## tar 'em up
cp VERSION.txt erl.ini.in CMakeLists.txt "${installdir}"
cd "${installdir}"

printf "# Contents of installdir:\n%s\n" "$(ls -la)"

tar --exclude="Install.exe" --exclude="Install.ini" --exclude="Uninstall.exe" -zcf ${thisdir}/${package_name_tgz} *
printf $(md5sum ${thisdir}/${package_name_tgz}) > ${thisdir}/${package_name_md5}
rm -f VERSION.txt erl.ini.in CMakeLists.txt

## uninstall the erlang installation
"${installdir}/Uninstall.exe" /S

rm -f VERSION.txt erl.ini.in CMakeLists.txt

echo "Build dir:"
ls -la "${thisdir}"

echo "end build at $(date)"
