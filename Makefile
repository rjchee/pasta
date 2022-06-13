TEST_CMD="bats"
TEST_DIR="test"

TMPDIR ?= "/tmp"

BINARY="pasta"
INSTALL_DIR ?= "/usr/local/bin/"

all:
	@echo "Pasta is just a shell script, so there is nothing to do. You can run \"make test\" to run tests."

test:
	@$(TEST_CMD) $(TEST_DIR)

clean:
	$(RM) -rf $(TMPDIR)/bats*

install:
	@cp $(BINARY) $(INSTALL_DIR)

.PHONY: test clean
