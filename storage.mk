# 存储设备相关，当前仅限 vdi

# 从 osboxes.org 下载 vdi
US_22.04:=$(SRC)/UbuntuServer22.04.vdi#Ubuntu Server 22.04 (64bit).vdi
ifeq ($(wildcard $(US_22.04)),)
$(US_22.04): /usr/local/bin/7zz /usr/local/bin/rename
	wget -P $(BUILD) https://zenlayer.dl.sourceforge.net/project/osboxes/v/vb/59-U-u-svr/22.04/64bit.7z
	7zz x $(BUILD)/64bit.7z -o$(BUILD)
	mv $(BUILD)/64bit/* $(SRC)
	rename 's/ |\(64bit\)//g' $(SRC)/*
/usr/local/bin/7z:; brew install 7-zip;
/usr/local/bin/rename:; brew install rename;
endif

# 从源码中解压 UbuntuServer22.04Guest.tar.gz。US=UbuntuServer
US_22.04.Guest:=$(SRC)/UbuntuServer22.04Guest.vdi
ifeq ($(wildcard $(US_22.04.Guest)),)
$(US_22.04.Guest): $(SRC)/UbuntuServer22.04Guest.tar.gz
	tar -xzvf $<

# 基于 osboxes vdi 改造。以下命令仅作为示例，实际需手动执行
$(US_22.04.Guest).bak: $(US_22.04)
#	启用 Host-only Networks 网络的 IP4，用于通过主机连接到客户机
	sudo sed -i.bak '/dhcp4: true/a\    enp0s8:\n      dhcp4:true' /etc/netplan/00-installer-config.yaml
#	添加 Guest Addition，用于通过 guestproperty 获取 IP 地址
	sudo mkdir -p /media/$(whoami)/VBox_GAs_7.0.6
	sudo mount -t iso9660 /dev/sr0 /media/$(whoami)/VBox_GAs_7.0.6
	cd /media/$(whoami)/VBox_GAs_7.0.6
	sudo apt install bzip2 -y
	sudo sh ./VBoxLinuxAdditions.run
endif

# 循环依赖，所以判断目标不存在源存在时，才执行
# make: Circular build/UbuntuServer22.04Guest.vdi <- src/UbuntuServer22.04Guest.vdi dependency dropped.
# 从源(vdi/压缩包)构建目标(vdi)
VDI_SRC_NAME?=UbuntuServer22.04Guest
$(BUILD)/%.vdi: $(SRC)/$(VDI_SRC_NAME).vdi $(BUILD)
	if [ ! -f $@ -a -f $< ]; then cp $< $@; fi

$(SRC)/%.vdi: $(SRC)/%.tar.gz
	if [ ! -f $@ -a -f $< ]; then cd $(SRC) && tar -xzvf $*.tar.gz; fi
#	tar -xzvf $<

# 从目标(vdi)构建源(vdi/压缩包)
$(SRC)/%.vdi: $(BUILD)/%.vdi $(SRC)
	if [ ! -f $@ -a -f $< ]; then cp $< $@; fi

$(SRC)/%.tar.gz: $(BUILD)/%.vdi $(SRC)
	if [ ! -f $@ -a -f $< ]; then cd $(BUILD) && tar -czvf ../$@ $*.vdi; fi # 压缩包不含 build 目录
#	tar -czvf $@ $< # 压缩包含 build 目录

# vdi 的账密，US=UbuntuServer
US_USER:=osboxes
US_PWD:=osboxes.org
