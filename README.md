# appimageutil

A command-line utility to generate AppImage

## appimageutil command usage

- **show help of this command**

    ```bash
    appimageutil -h
    appimageutil --help
    ```

- **show version of this command**

    ```bash
    appimageutil -v
    appimageutil --version
    ```

- **show basic information about this software**

    ```bash
    appimageutil about
    ```

- **show basic information about your current running operation system**

    ```bash
    appimageutil sysinfo
    ```

- **create a new AppImage file from AppDir**

    ```bash
    appimageutil create app.AppDir

    appimageutil create app.tar.gz

    appimageutil create app/ -o xx.AppImage -- -comp xz -b 16384 -Xdict-size 100% -root-owned -noappend
    ```

## environment variables

- **APPIMAGEUTIL_VERBOSE**

    assign to `1` if you want to enable verbose mode.

- **APPIMAGEUTIL_CORE_PATH**

    assign to the full path of appimageutil-core. default to `&/core`, `&` represents the directory where the `appimageutil` command is located in.

- **SSL_CERT_FILE**

    assign to the cacert.pem file path. default to `&/core/cacert.pem`, `&` represents the directory where the `appimageutil` command is located in.

    ```bash
    curl -LO https://curl.se/ca/cacert.pem
    export SSL_CERT_FILE="$PWD/cacert.pem"
    ```

    In general, you don't need to set this environment variable, but, if you encounter the reporting `the SSL certificate is invalid`, trying to run above commands in your terminal will do the trick.

## appimageutil-core

appimageutil-core is a set of essential command-line tools and resources that are used by appimageutil.

command-line tools:

- [xxd](https://man.archlinux.org/man/xxd.1.en)
- [gpg](https://man.archlinux.org/man/gpg.1.en)
- [tree](https://man.archlinux.org/man/tree.1.en)
- [find](https://man.archlinux.org/man/find.1.en)
- [curl](https://man.archlinux.org/man/curl.1.en)
- [bsdtar](https://man.archlinux.org/man/core/libarchive/bsdtar.1.en)
- [sysinfo](https://github.com/leleliu008/sysinfo)
- [zsyncmake](https://man.archlinux.org/man/zsyncmake.1.en)
- [mksquashfs](https://man.archlinux.org/man/mksquashfs.1.en)
- [appstreamcli](https://man.archlinux.org/man/appstreamcli.1.en)
- [desktop-file-validate](https://man.archlinux.org/man/desktop-file-validate.1.en)

resources:

- [cacert.pem](https://curl.se/ca/cacert.pem)
