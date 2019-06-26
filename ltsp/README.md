# Directory contents
* client: applets that can only be run by LTSP clients
* common: applets that can be run by LTSP clients or servers
* configs: files used by `ltsp config xxx`; maybe they should be moved inside
  the config applet directories
* initrd: code to be included in the ltsp.img initramfs
* server: applets that can only be run by LTSP servers
* ltsp: the main LTSP entry point; symlinked in /usr/sbin
