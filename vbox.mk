# 虚拟机相关
# 以下代码在 macOS 运行测试
# 命令手册：https://www.virtualbox.org/manual/ch08.html
vbox.init: vbox.create vbox.additions;
VBOXMANAGE:=/usr/local/bin/VBoxManage
vbox.create: $(VBOXMANAGE)
# 可选条件
vbox.additions: vbox.hostonlynet.add; # vbox.extpack.install;

# 安装 vbox
VBOX_VERSION:=7.0.10
VBOX_INSTALLED:=$(wildcard $(VBOXMANAGE))
ifeq ($(VBOX_INSTALLED),)
$(VBOXMANAGE): $(BREW); brew install virtualbox
else

# GitHub Action 中 macOS 已经安装了 6.x 版本的 virtualbox，删除低版本，安装高版本
VBOX_VERSION:=$(firstword $(subst ., ,$(shell VBoxManage -v)))
ifeq ($(VBOX_VERSION),6)
$(info $(shell sudo rm -rf /Applications/VirtualBox.app))
$(info brew install virtualbox: $(shell brew install virtualbox))
endif

#$(info VBoxManage -v: $(shell VBoxManage -v))
endif

BREW:=/usr/local/bin/brew
$(BREW):
	if command -v brew; then brew -v else /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" fi

# 下载安装包到 SRC 目录
VBOX_NAME:=VirtualBox-7.0.10a-158379-OSX.dmg
VBOX_SRC:=$(SRC)/$(VBOX_NAME)
# 已经存在该文件，但仍可能执行内容以更新文件
ifeq ($(wildcard $(VBOX_SRC)),)
$(VBOX_SRC):; wget -P $(SRC) https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/$(VBOX_NAME);
endif

# 安装扩展包，需要密码确认
vbox.extpack.install: $(VBOXMANAGE) $(EXTPACK_SRC)
	yes | vboxmanage extpack install $(word 2,$^)

# 下载扩展包到 SRC 目录
EXTPACK_NAME:=Oracle_VM_VirtualBox_Extension_Pack-7.0.10.vbox-extpack
EXTPACK_SRC:=$(SRC)/$(EXTPACK_NAME)
ifeq ($(wildcard $(EXTPACK_SRC)),)
$(EXTPACK_SRC):; wget -P $(SRC) https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/$(EXTPACK_NAME);
endif

# 查看虚拟机信息
vbox.list.subdir:; make vbox.list BUILD=$(BUILD)/vbox
vbox.list: $(addsuffix .vbox.list,$(addprefix $(BUILD)/,ostypes natnets hostonlynets extpacks vms));
$(BUILD)/%.vbox.list: $(BUILD); vboxmanage list $* > $@

# 获取网络名称，gsub 删除前置空格
$(BUILD)/%.vbox.name: $(BUILD)/%.vbox.list
	cat $< | grep -w Name | awk -F':' '{print $$NF}' | awk '{gsub(/^ +/, ""); print $$0}' > $@

# Host Only Network management
vbox.hostonlynet.add:
	VBoxManage hostonlynet add --name=vboxnet1 --netmask=255.255.255.0 --lower-ip=192.168.150.3 --upper-ip=192.168.150.254 --enable

# 残缺的生命周期测试
vbox.lifecycle.test: vbox.init vbox.list.subdir;
