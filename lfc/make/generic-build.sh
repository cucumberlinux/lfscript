#!/bin/bash
# Version 2017-04-28

# Generic Compilation Script for Java projects (using Avian and UPX)
# Copyright (c) 2011-2017 Marcel van den Boer
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# NOTICE:
#   Run this script without arguments to see usage instructions.

set -e

main() {
    local DEFAULT_JAVA_HOME="/usr/lib/jvm/default-java
                             /usr/lib/jvm/java-6-openjdk-armhf
                             /usr/lib/jvm/java-6-openjdk-amd64
                             /usr/lib/jvm/java-6-openjdk
                             /usr/lib/jvm/java-7-openjdk-armhf
                             /usr/lib/jvm/java-7-openjdk-amd64
                             /usr/lib/jvm/java-7-openjdk
                             /usr/lib/jvm/java-8-openjdk-armhf
                             /usr/lib/jvm/java-8-openjdk-amd64
                             /usr/lib/jvm/java-8-openjdk
                             /usr/lib/jvm/java-9-openjdk-armhf
                             /usr/lib/jvm/java-9-openjdk-amd64
                             /usr/lib/jvm/java-9-openjdk"

    if [ "${JAVA_HOME}" == "" ]; then
        echo -n "Autodetecting JAVA_HOME... "

        for dir in ${DEFAULT_JAVA_HOME}; do
            if [ -d "${dir}" ]; then
                export JAVA_HOME="${dir}"
                echo "${JAVA_HOME}"
                break
            fi
        done

        if [ "${JAVA_HOME}" == "" ]; then
            echo "Failed."
            echo "Please set 'JAVA_HOME' manually."
            exit 1
        fi
    fi

    pushd java
    rebuild_$@
    popd
}

rebuild_clean() {
    rm -rf ../build
}

rebuild_pure() {
    rm -rf ../3rdparty
}

rebuild_purge() {
    rebuild_clean
    rebuild_pure
}

rebuild_jar() {
    if [ "${JARNAME}" == "" ]; then
        echo "ERROR: 'JARNAME' not set."
        exit 1
    fi

    rm -rf ../build/class
    mkdir -p ../build/class

    "${JAVA_HOME}/bin/javac" -d ../build/class $(find . -name *.java)

    pushd ../build/class

    "${JAVA_HOME}/bin/jar" cf ../${JARNAME} *

    popd

    rm -rf ../build/class
}

rebuild_api() {
    rm -rf ../build/api

    "${JAVA_HOME}/bin/javadoc" -d ../build/api -sourcepath . \
        -link http://download.oracle.com/javase/6/docs/api/ @options
}

rebuild_bin() {
    mkdir -p ../build
    mkdir -p ../3rdparty
    cd ../3rdparty

    # Set up architecture
    case $(uname -m) in
        i?86)
            local ARCH="i386"
            local UPX_ARCH="${ARCH}"
            local UPX_MD5="6f0c4410acc4d7ccd903e4d180d2c559"
            ;;
        x86_64)
            local ARCH="x86_64"
            local UPX_ARCH="amd64"
            local UPX_MD5="3902db7ec65c115ea9dc4581bb840849"
            ;;
        arm*)
            local ARCH="arm"
            local UPX_ARCH="armeb"
            local UPX_MD5="6d07679933c785214cbf40ee8fe542e9"
            ;;
        *)
            echo "Unknown architecture: $(uname -m)" >&2
            ;;
    esac

    # Fetch UPX
    local UPX_FOL="upx-3.93-${UPX_ARCH}_linux"
    local TGZ="${UPX_FOL}.tar.xz"
    if [ ! -r ${TGZ} ]; then
        echo "Downloading UPX..."
        wget http://upx.sourceforge.net/download/${TGZ}
        if [ "$(md5sum ${TGZ})" != "${UPX_MD5}  ${TGZ}" ]; then
            echo "MD5 checksum failure"
            return 1
        fi
    fi
    rm -rf ../build/${UPX_FOL}
    cd ../build
    tar xf ../3rdparty/${TGZ}
    cd ../3rdparty

    # Fetch Avian
    #local AVIAN_VERSION="46c648d386ca6ba998d9e493ecaa27b6eea265f0" # 1.0.4 (for Ubuntu 10.04)
    local AVIAN_VERSION="16dd804f392168497fa17ab682978f938e291bfb" # commit of March 22nd, 2017
    local AVIAN_FOL="avian"
    pushd ../build
    rm -rf ${AVIAN_FOL}
    git clone https://github.com/ReadyTalk/avian.git
    pushd avian
    git checkout ${AVIAN_VERSION}
    popd
    popd

    # Build Avian
    cd ../build/${AVIAN_FOL}
    make
    cp build/linux-${ARCH}/avian ../vm-${ARCH}
    cd ../
    strip --strip-all vm-${ARCH}
    ./${UPX_FOL}/upx --lzma --best vm-${ARCH}

    rm -rf ${AVIAN_FOL} ${UPX_FOL}
}

if [ "${1}" == "" ]; then
    echo ""
    echo "Usage: bash ${0} [option]"
    echo ""
    echo "Files:"
    echo "  Source code should be present in a folder called 'java'. The file"
    echo "  'java/options' should be present and should contain at least the"
    echo "  name of one package to document, if you want to generate API"
    echo "  documentation."
    echo "  All output is placed in a folder called 'build'. Any downloaded"
    echo "  third party applications are placed in a folder called '3rdparty'."
    echo ""
    echo "Options:"
    echo "   jar      -  Build a jar file containing the entire class library"
    echo "   bin      -  Build Avian VM"
    echo "   api      -  Build API documentation"
    echo ""
    echo "   clean    -  Remove all built files"
    echo "   pure     -  Remove all downloaded 3rd party files"
    echo "   purge    -  Same as running both 'clean' and 'pure'"
    echo ""
    echo "Be sure to set the variable 'JARNAME', when using option 'jar'."
    echo ""
    echo "Additionally, you may want to set the JAVA_HOME variable to the"
    echo "location of your JDK, otherwise a default value is used."
    echo ""
else
    main $@
fi

