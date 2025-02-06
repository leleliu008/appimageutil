#!/bin/sh

# Copyright (c) 2025-2025 刘富频
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


VERSION=0.1.0

COLOR_RED='\033[0;31m'          # Red
COLOR_GREEN='\033[0;32m'        # Green
COLOR_YELLOW='\033[0;33m'       # Yellow
COLOR_BLUE='\033[0;94m'         # Blue
COLOR_PURPLE='\033[0;35m'       # Purple
COLOR_OFF='\033[0m'             # Reset

abort() {
    EXIT_STATUS_CODE="$1"
    shift
    printf '%b\n' "${COLOR_RED}💔  appimageutil: $*${COLOR_OFF}" >&2
    exit "$EXIT_STATUS_CODE"
}

run() {
    if [ "$APPIMAGEUTIL_VERBOSE" = 1 ] ; then
        printf '%b\n' "${COLOR_PURPLE}==>${COLOR_OFF} ${COLOR_GREEN}$*${COLOR_OFF}"
    fi

    eval "$@"
}

help() {
    printf '%b\n' "\
${COLOR_GREEN}A command-line utility to generate AppImage${COLOR_OFF}

${COLOR_GREEN}$ARG0 --help${COLOR_OFF}
${COLOR_GREEN}$ARG0 -h${COLOR_OFF}
    show help of this command.

${COLOR_GREEN}$ARG0 --version${COLOR_OFF}
${COLOR_GREEN}$ARG0 -v${COLOR_OFF}
    show version of this command.

${COLOR_GREEN}$ARG0 create <INPUT-PATH> [OPTIONS] [-- [mksquashfs OPTIONS]]${COLOR_OFF}
    create a new AppImage file from AppDir.

    ${COLOR_GREEN}<INPUT-PATH>${COLOR_OFF} can be either the filepath or directory. If <INPUT-PATH> is a filepath, it will be unpacked via bsdtar.

    ${COLOR_GREEN}OPTIONS:${COLOR_OFF}
        ${COLOR_BLUE}-o <OUTPUT-PATH>${COLOR_OFF}
            specify where the AppImage file will be written to.

            <OUTPUT-PATH> can be either the filepath or directory.

            If <OUTPUT-PATH> ends with slash, it will be treated as a directory, otherwise, it will be treated as a filepath.

            If <OUTPUT-PATH> is treated as a directory, the AppImage filename would be <PACKAGE-NAME>-<TARGET-ARCH>.AppImage

            If <OUTPUT-PATH> is unspecified, the AppImage filename would be <PACKAGE-NAME>-<TARGET-ARCH>.AppImage

        ${COLOR_BLUE}-v${COLOR_OFF}
            verbose mode. many messages will be output to terminal.

        ${COLOR_BLUE}-x${COLOR_OFF}
            set -x to this shell script.

        ${COLOR_BLUE}--no-appstream${COLOR_OFF}
            Do not check AppStream metadata.

        ${COLOR_BLUE}--sign${COLOR_OFF}
            generate signature with gpg.

        ${COLOR_BLUE}--sign-key <KEY>${COLOR_OFF}
            specify gpg sign key. automatically apply --sign

    ${COLOR_GREEN}mksquashfs OPTIONS:${COLOR_OFF}
        refer to https://manpages.debian.org/jessie/squashfs-tools/mksquashfs.1.en.html

        appimageutil use ${COLOR_RED}-comp zstd -b 128K -root-owned -noappend${COLOR_OFF} mksquashfs options by default, you can change this behaver, for example:

        ${COLOR_RED}appimageutil create app/ -o xx.AppImage -- -comp xz -b 16384 -Xdict-size 100% -root-owned -noappend${COLOR_OFF}

    ${COLOR_GREEN}influential environment variables:${COLOR_OFF}
        ${COLOR_BLUE}APPIMAGEUTIL_VERBOSE${COLOR_OFF}
            assign to 1 if you want to enable verbose mode.

        ${COLOR_BLUE}APPIMAGEUTIL_CORE_PATH${COLOR_OFF}
            assign to the appimageutil-core directory. default to ./core/

        ${COLOR_BLUE}SSL_CERT_FILE${COLOR_OFF}
            assign to the cacert.pem file path. default to ./core/cacert.pem
    "
}

create() {
    unset APPDIR
    unset APPARCHIVEFILEPATH

    [ -z "$1" ] && abort 1 "Usage: $ARG0 create <APPDIR|APP_ARCHCHIVE_FILEPATH> [OPTIONS] [-- [mksquashfs OPTIONS]]"

    if [ -d "$1" ] ; then
        APPDIR="$1"
    elif [ -f "$1" ] ; then
        APPARCHIVEFILEPATH="$1"
    else
        abort 1 "derecotory or file does not exist: $1"
    fi

    shift

    ############################################################################

    unset OUTPUT_PATH
    unset SIGN_ARGS
    unset SIGN_WITH_GPG

    CHECK_APPSTREAM=1

    while [ -n "$1" ]
    do
        case $1 in
            -o) shift
                OUTPUT_PATH="$1"
                ;;
            -v) APPIMAGEUTIL_VERBOSE=1 ;;
            -x) APPIMAGEUTIL_VERBOSE=1
                set -x
                ;;
            --no-appstream)
                CHECK_APPSTREAM=0
                ;;
            --sign)
                SIGN_WITH_GPG=1
                ;;
            --sign-key)
                shift
                [ -z "$1" ] && abort 1 "--sign-key is given, but no value specified."
                SIGN_ARGS="--sign-key $1"
                SIGN_WITH_GPG=1
                ;;
            --) shift
                break
                ;;
            *)  abort 1 "Usage: $ARG0 create <INPUT> [OPTIONS] [-- [mksquashfs OPTIONS]], unrecognized option: $1"
        esac
        shift
    done

    ############################################################################

    INITPWD="$PWD"

    unset SESSION_DIR

    ############################################################################

    if [ -z "$APPDIR" ] ; then
        SESSION_DIR="$(mktemp -d)"
        APPDIR="$SESSION_DIR/AppDir"

        run install -d "$APPDIR"
        run bsdtar xf "$APPARCHIVEFILEPATH" -C "$APPDIR" --strip-components 1
    fi

    ############################################################################

    run cd "$APPDIR"

    ############################################################################

    unset DESKTOP_FILEPATH

    for item in *
    do
        case $item in
            *.desktop)  DESKTOP_FILEPATH="$item"
        esac
    done

    if [ -z "$DESKTOP_FILEPATH" ] ; then
        DESKTOP_FILEPATH="$(find \( -type f -or -type l \) -name '*.desktop' -print -quit)"
    fi

    if [ -z "$DESKTOP_FILEPATH" ] ; then
        abort 1 'no .desktop file was found.'
    fi

    run desktop-file-validate "$DESKTOP_FILEPATH"

    ############################################################################

    if [ "$CHECK_APPSTREAM" = 1 ] ; then
        run appstreamcli validate-tree .
    fi

    ############################################################################

    if [ -z "$SESSION_DIR" ] ; then
        SESSION_DIR="$(mktemp -d)"
    fi

    ############################################################################

    unset TARGET_ARCH

    find -type f > "$SESSION_DIR/fs.txt"

    while read -r FILEPATH
    do
        FILEMAGIC="$(xxd -u -p -l 4 "$FILEPATH")"

        # http://www.sco.com/developers/gabi/latest/ch4.eheader.html
        if [ "$FILEMAGIC" = '7F454C46' ] ; then
            ELF_ARCH="$(xxd -u -p -s 18 -l 2 "$FILEPATH")"

            case $ELF_ARCH in
                0300) TARGET_ARCH='x86'     ;;
                3E00) TARGET_ARCH='x86_64'  ;;
                B700) TARGET_ARCH='aarch64' ;;
                F300) TARGET_ARCH='riscv64' ;;
                1500) TARGET_ARCH='ppc64le' ;;
                0201) TARGET_ARCH='loongarch64' ;;
                0016) TARGET_ARCH='3390x'   ;;
                2800) 
                    ELF_FLAGS="$(xxd -u -p -s 36 -l 4 "$FILEPATH")"

                    case $ELF_FLAGS in
                        00040005) TARGET_ARCH='armhf' ;;
                        02000005) TARGET_ARCH='armv7' ;;
                    esac
            esac

            break
        fi
    done < "$SESSION_DIR/fs.txt"

    [ -z "$TARGET_ARCH" ] && abort 1 'could not determine target arch.'

    ############################################################################

    run cd "$SESSION_DIR"

    ############################################################################

    run curl -L -o runtime https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-$TARGET_ARCH

    ############################################################################

    if [ -z "$@" ] ; then
        run mksquashfs "$APPDIR" squashfs -comp zstd -b 128K -root-owned -noappend
    else
        run mksquashfs "$APPDIR" squashfs "$@"
    fi

    ############################################################################

    run 'cat runtime squashfs > AppImage'

    run du -sh AppImage

    run chmod a+x AppImage

    ############################################################################

    if [ "$SIGN_WITH_GPG" = 1 ] ; then
        run gpg --sign --output AppImage.sig AppImage $SIGN_ARGS
    fi

    ############################################################################

    if [ -n "$OUTPUT_PATH" ] ; then
        case $OUTPUT_PATH in
            */) OUTPUT_DIR="$OUTPUT_PATH"
                DESKTOP_FILENAME="${DESKTOP_FILEPATH##*/}"
                APPNAME="${DESKTOP_FILENAME%.desktop}"
                OUTPUT_FILENAME="$APPNAME-$TARGET_ARCH.AppImage"
                ;;
            *)  OUTPUT_DIR="$(dirname "$OUTPUT_PATH")/"
                OUTPUT_FILENAME="${OUTPUT_PATH##*/}"
        esac

        if [ ! -d "$OUTPUT_DIR" ] ; then
            run install -d "$OUTPUT_DIR"
        fi
    else
        DESKTOP_FILENAME="${DESKTOP_FILEPATH##*/}"
        APPNAME="${DESKTOP_FILENAME%.desktop}"
        OUTPUT_DIR=.
        OUTPUT_FILENAME="$APPNAME-$TARGET_ARCH.AppImage"
    fi

    ############################################################################

    run mv AppImage "$OUTPUT_FILENAME"

    if [ "$SIGN_WITH_GPG" = 1 ] ; then
        run mv AppImage.sig "$OUTPUT_FILENAME.sig"
    fi

    ############################################################################

    if [ -n "$GITHUB_REPOSITORY" ] ; then
        URL="https://github.com/$GITHUB_REPOSITORY/releases/download/"

        run zsyncmake -u "$URL" "$OUTPUT_FILENAME"
    fi

    ############################################################################

    run cd "$INITPWD"
    run mv "$SESSION_DIR/$OUTPUT_FILENAME" "$OUTPUT_DIR"

    #run rm -rf "$SESSION_DIR"
}

set -e

# If IFS is not set, the default value will be <space><tab><newline>
# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_05_03
unset IFS

ARG0="$0"

case $1 in
    ''|--help|-h)
        help
        ;;
    --version|-v)
        printf '%s\n' "$VERSION"
        ;;
    create)
        if [ -z "$APPIMAGEUTIL_CORE_PATH" ] ; then
            cd "$(dirname "$0")"

            APPIMAGEUTIL_CORE_PATH="$PWD/core"

            cd - > /dev/null
        fi

        if [ -d "$APPIMAGEUTIL_CORE_PATH" ] ; then
            export PATH="$APPIMAGEUTIL_CORE_PATH:$PATH"

            if [ -z "$SSL_CERT_FILE" ] ; then
                # https://www.openssl.org/docs/man1.1.1/man3/SSL_CTX_set_default_verify_paths.html
                export SSL_CERT_FILE="$APPIMAGEUTIL_EXEC_PATH/cacert.pem"

                if [ ! -f "$SSL_CERT_FILE" ] ; then
                    unset   SSL_CERT_FILE
                fi
            fi
        fi

        shift

        create "$@"
        ;;
    *)  abort 1 "unrecognized argument: $1"
esac
