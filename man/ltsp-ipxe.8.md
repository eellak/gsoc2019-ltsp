## NAME
**ltsp ipxe** - install iPXE binaries and configuration in TFTP

## SYNOPSIS
**ltsp** [_ltsp-options_] **ipxe** [**-u** _binaries-url_]

## DESCRIPTION
Install iPXE binaries and configuration in $TFTP_DIR/ltsp:
 * ltsp.ipxe: iPXE configuration file
 * memtest.0: memtest binary for BIOS mode
 * memtest.efi: memtest binary for UEFI mode
 * snponly.efi: iPXE binary for UEFI mode
 * undionly.kpxe: iPXE binary for BIOS mode

These binaries are periodically copied from https://boot.ipxe.org to
github to avoid straining ipxe.org and to provide the same versions to
most LTSP users.

Note that this LTSP applet requires Internet connectivity. Otherwise
you would need to manually transfer the binaries to TFTP before running
`ltsp ipxe` to generate the configuration.

You may edit the generated ltsp.ipxe to customize the menus etc,
but remember not to accidentally overwrite it in the future.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-u**, **--binaries-url=**_URL_
  Specify a different URL for the binaries. Defaults to
  https://github.com/ltsp/binaries/releases/latest/download.

## EXAMPLES
Force downgrading to an older version of the binaries:
```shell
ltsp -o ipxe -u 'https://github.com/ltsp/binaries/releases/download/v19.07'
```

Copy the binaries from a USB stick before running ltsp ipxe:
```shell
mkdir -p /srv/tftp/ltsp
cd /media/administrator/usb-stick
cp {memtest.0,memtest.efi,snponly.efi,undionly.kpxe} /srv/tftp/ltsp
ltsp ipxe
```

