# Replacement of LTSP

## Introduction
LTSP (Linux Terminal Service Project) allows diskless workstations to be netbooted from a single server image, with centralized authentication and home directories. But the project shows its age; the initial thin-client focused design is no longer suitable for the netbooted fat client/wayland era, and it contains a lot of stale source code. This GSoC project is about designing and implementing a modern replacement of LTSP.

## Project goals
A modern replacement of LTSP will be implemented, as outlined in http://wiki.ltsp.org/wiki/Dev:GSoC. It will be ready for inclusion in Debian/Ubuntu, for LTSP users to be able to slowly migrate to it.

Coding will start from a clean tree and some bits of LTSP code will be imported when necessary. The following parts will be deprecated and replaced with newer methods:
 - Only fat clients will be supported. Thin clients will be replaced by xfreerdp or other remote desktop methods that will work with Wayland.
 - That implies that ltsp-localapps won't be supported, as all processes will be running locally on the client anyway.
 - Additionally, ltsp-remoteapps won't exist. Only processes started via xfreerdp will be remote (i.e. running on the server).
 - LTSPFS, for forwarding local file systems remotely to the server, will be replaced by xfreerdp folder sharing.
 - Generating chroots with `ltsp-build-client` will be replaced by VirtualBox VMs or other methods.
 - Replicating the server disk currently done with `ltsp-update-image -c /` will still be supported.
 - The LTSP Display Manager, LDM, doesn't support Wayland. It will be either rewritten in Python3/Gtk3, or replaced with some PAM-based authentication method.

## Timeline
The implementation details follow, organized by [GSoC timeline](https://developers.google.com/open-source/gsoc/timeline).

### Student application work (Mar 25 - Apr 09)
As part of the application process, I investigated netbooting LTSP clients under UEFI. I examined the following applications:
 - shim.efi: for secure boot
 - ipxe.efi, snponly.efi: boot loader mostly used for netbooting
 - grub.efi: boot loader mostly used in local installations
 - syslinux.efi: boot loader mostly used in live CDs

I discovered and reported the following related bugs:
 - shim upstream: [Shim uses wrong TFTP server IP in proxyDHCP mode](https://github.com/rhboot/shim/issues/165)
 - shim in launchpad: [Shim uses wrong TFTP server IP in proxyDHCP mode](https://bugs.launchpad.net/ubuntu/+source/shim/+bug/1813541)
 - grub upstream: [Wrong TFTP server when booted from proxyDHCP](https://savannah.gnu.org/bugs/index.php?55636)
 - ipxe in launchpad: [Make grub-ipxe work under UEFI](https://bugs.launchpad.net/ubuntu/+source/ipxe/+bug/1811496)

### Community Bonding Period (May 6 - May 26)
While the LTSP codebase has been actively maintained, the ltsp.org website hasn't seen any updates since 2013. The server itself is an Ubuntu 10.04 Virtual Machine, which was EOLed in April 2015 and suffers from security issues and [excessive spam](http://wiki.ltsp.org/wiki/Special:NewPages).

I will try to contact the ltsp.org domain owners to see if they're interested in transferring the domain to the LTSP community, in which case I'll set up a web server and a new site for it. Otherwise, I will set up a new project with a different name under github.com or gitlab.com.

### Phase 1 (May 27 - Jun 28)
The equivalent of the "ltsp-client" package will be implemented, which allows clients to be netbooted.
 - initramfs helpers for netbooting
 - init-ltsp.d scripts for dynamic configuration
At this point, it'll still be using the LDM display manager, or the distribution display manager with fixed (non SSH) accounts.

Deprecated: screen scripts, ltspfs, ltsp-genmenu, ltsp-open, ltsp-localappsd, ltsp-remoteapps, update-kernels.

### Phase 2 (Jun 29 - Jul 26)
The equivalent of the "ltsp-server" package will be implemented, which configures a netbooting server, and provides utilities for managing the client virtual disks.
 - ltsp-chroot, ltsp-update-image, ltsp-update-kernels, ltsp-config
 - Support for both BIOS and UEFI systems
 
 Deprecated: ltsp-build-client, ltsp-localapps.

### Phase 3 (Jul 27 - Aug 26)
The equivalent of the "ldm" package will be implemented, that netbooted clients use for authentication / login.
 - Either with libpam-sshauth, or similar,
 - Or as a lightdm greeter,
 - Or a reimplementation of LDM in Python3/Gtk3, so that it can run under wayland too.

The whole project will be packaged and submitted to Debian.

### Follow up
Starting from Sep 2019, it will be used in Greek schools, where it will get real world testing, and any discovered issues will be resolved.

## Links
* http://www.ltsp.org/
* http://wiki.ltsp.org/wiki/Dev:GSoC
