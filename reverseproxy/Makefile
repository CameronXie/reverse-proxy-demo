dist:=_dist
version:=$(shell git rev-parse --short HEAD)

build: install-dependency
	@rm -rf ${dist}
	@make build-publisher

build-publisher:
	@go build -o ${dist}/reverseproxy-$(version) .

install-dependency:
	@go mod vendor