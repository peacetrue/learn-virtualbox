$(SRC)/%.tar.gz: $(SRC)/%.vdi
	@ls -lh $<
	tar -czvf $@ $<
	@ls -lh $@
$(SRC)/%.vdi: $(SRC)/%.tar.gz
	@ls -lh $<
	tar -xzvf $<
	@ls -lh $@

# make src/UbuntuServer22.04Guest.tar.gz
# make src/UbuntuServer22.04Guest.vdi
# make src/b.tar.gz
# make rm/src/a.vdi src/a.vdi
# make src/a.vdi
