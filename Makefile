# https://www.virtualbox.org/manual/UserManual.html
# https://www.virtualbox.org/manual/UserManual.html#vboxmanage
.SECONDARY:#保留中间过程文件
include build.common.mk
include vbox.mk
include storage.mk
include guest.mk


