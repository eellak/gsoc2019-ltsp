dist_man_MANS = ltsp-chroot.8 ltsp-config.8 ltsp-info.1 \
	ltsp-update-image.8 ltsp-update-kernels.8 ltsp-update-sshkeys.8 \
	ltsp-build-client.8 lts.conf.5
H2M_COMMON_FLAGS = -N --include="include/common.h2m"

ltsp-build-client.8: ../ltsp-build-client
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-build-client.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-build-client.h2m" \
	--name="build an LTSP client system for use with the LTSP server" \
	--help-option="--extra-help" ../ltsp-build-client

ltsp-chroot.8: ../ltsp-chroot
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-chroot.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-chroot.h2m" \
	--name="chroot into a specific LTSP thin client chroot" \
	../ltsp-chroot

ltsp-config.8: ../ltsp-config
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-config.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-config.h2m" \
	 --name="configure certain parts of an LTSP server" \
	../ltsp-config

ltsp-info.1: ../ltsp-info
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-info.1 \
	-s 1 $(H2M_COMMON_FLAGS) --include="include/ltsp-info.h2m" \
	--name="display troubleshooting information about ltsp server and chroots" \
	../ltsp-info

ltsp-update-image.8: ../ltsp-update-image
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-update-image.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-update-image.h2m" \
	--name="generate an NBD image from an LTSP chroot" \
	../ltsp-update-image

ltsp-update-kernels.8: ../ltsp-update-kernels
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-update-kernels.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-update-kernels.h2m" \
	--name="copy LTSP chroot kernels to TFTP directories" \
	../ltsp-update-kernels

ltsp-update-sshkeys.8: ../ltsp-update-sshkeys
	MODULES_BASE="../share/ltsp" $(HELP2MAN) -o ltsp-update-sshkeys.8 \
	-s 8 $(H2M_COMMON_FLAGS) --include="include/ltsp-update-sshkeys.h2m" \
	--name="update LTSP chroots to trust the server ssh keys" \
	../ltsp-update-sshkeys

lts.conf.5:
	go-md2man -in=lts.conf.5.md -out=lts.conf.5
