.PHONY: check deps test

check: test
	mix dialyzer

deps:
	mix deps.get

test:
	mix test
