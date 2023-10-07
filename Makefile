# https://www.virtualbox.org/manual/UserManual.html#vboxmanage
# 硬链接当前目录下 mk 文件到其他目录，以实现同步
# ls $workingDir/learn-virtualbox | grep mk | xargs -I {} ln $workingDir/learn-virtualbox/{} {}
.SECONDARY:#保留中间过程文件
include build.common.mk
include vbox.mk
include storage.mk
include guest.mk


