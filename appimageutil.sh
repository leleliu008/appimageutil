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

print() {
    printf '%b' "$*"
}

echo() {
    printf '%b\n' "$*"
}

note() {
    printf '%b\n' "${COLOR_YELLOW}🔔  $*${COLOR_OFF}" >&2
}

warn() {
    printf '%b\n' "${COLOR_YELLOW}⚠️  $*${COLOR_OFF}" >&2
}

success() {
    printf '%b\n' "${COLOR_GREEN}✅️  $*${COLOR_OFF}" >&2
}

error() {
    printf '%b\n' "${COLOR_RED}💔  appimageutil: $*${COLOR_OFF}" >&2
}

abort() {
    EXIT_STATUS_CODE="$1"
    shift
    printf '%b\n' "${COLOR_RED}💔  appimageutil: $*${COLOR_OFF}" >&2
    exit "$EXIT_STATUS_CODE"
}

run() {
    echo "${COLOR_PURPLE}==>${COLOR_OFF} ${COLOR_GREEN}$@${COLOR_OFF}"
    eval "$@"
}

__help() {
    printf '%b\n' "
${COLOR_GREEN}A command-line utility to generate AppImage.${COLOR_OFF}

${COLOR_GREEN}$ARG0 --help${COLOR_OFF}
${COLOR_GREEN}$ARG0 -h${COLOR_OFF}
    show help of this command.

${COLOR_GREEN}$ARG0 --version${COLOR_OFF}
${COLOR_GREEN}$ARG0 -v${COLOR_OFF}
    show version of this command.

${COLOR_GREEN}$ARG0 bundle <INPUT-PATH> [OPTIONS] [-- [mksquashfs OPTIONS]]${COLOR_OFF}
    generate the AppImage file from AppDir.

    ${COLOR_BLUE}<INPUT-PATH>${COLOR_OFF}
        should end with any one of / .tar.gz .tar.xz .tar.lz .tar.bz2 .zip

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
        specify gpg sign key.


    mksquashfs OPTIONS:
        refer to https://manpages.debian.org/jessie/squashfs-tools/mksquashfs.1.en.html

    USAGE-EXAMPLES:
        appimageutil bundle app/
        appimageutil bundle app/                -- -comp xz -b 16384 -Xdict-size 100% -root-owned -noappend
        appimageutil bundle app/ -o xx.AppImage -- -comp xz -b 16384 -Xdict-size 100% -root-owned -noappend
    "
}

__bundle() {
    unset APPDIR
    unset APPARCHIVEFILEPATH

    case $1 in
        '') abort 1 "Usage: $ARG0 bundle <APPDIR|APP_ARCHCHIVE_FILEPATH> [OPTIONS] [-- [mksquashfs OPTIONS]]"
            ;;
        *.tar.[glx]z|*.tar.bz2|*.zip)
            [ -f "$1" ] || abort 1 "input file does not exist: $1"
            APPARCHIVEFILEPATH="$1"
            ;;
        */)
            [ -d "$1" ] || abort 1 "input directory does not exist: $1"
            APPDIR="$1"
            ;;
        *)  abort 1 "Usage: $ARG0 bundle <INPUT> [OPTIONS] [-- [mksquashfs OPTIONS]], <INPUT> should end with any one of / .tar.gz .tar.xz .tar.lz .tar.bz2 .zip"
    esac

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
            -v) ;;
            -x) set -x
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
                ;;
            --) shift
                break
                ;;
            *)  abort 1 "Usage: $ARG0 bundle <INPUT> [OPTIONS] [-- [mksquashfs OPTIONS]], unrecognized option: $1"
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
                0300) TARGET_ARCH='i686'    ;;
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
                        02000005) TARGET_ARCH='arm'   ;;
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

    cat runtime  >> AppImage
    cat squashfs >> AppImage

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

    run mv AppImage       "$OUTPUT_FILENAME"
    run mv AppImage.sig   "$OUTPUT_FILENAME.sig"

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
        __help
        ;;
    --version|-v)
        printf '%s\n' "$VERSION"
        ;;
    check)
        shift
        __check "$@"
        ;;
    bundle)
        cd "$(dirname "$0")"

        # https://www.openssl.org/docs/man1.1.1/man3/SSL_CTX_set_default_verify_paths.html
        #export SSL_CERT_FILE="$PWD/cacert.pem"

        export PATH="$PWD:$PATH"

        cd - > /dev/null

        shift

        __bundle "$@"
        ;;
    *)  abort 1 "unrecognized argument: $1"
esac
