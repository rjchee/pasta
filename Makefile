TEST_CMD="bats"
TEST_DIR="test"

TMPDIR ?= "/tmp"

all:
	@echo "Pasta is just a shell script, so there is nothing to do. You can run \"make test\" to run tests."

test:
	@$(TEST_CMD) $(TEST_DIR)

clean:
	$(RM) -rf $(TMPDIR)/bats*

.PHONY: test clean
