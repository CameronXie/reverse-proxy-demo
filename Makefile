services:=reverseproxy
version:=$(shell git rev-parse --short HEAD)
env:=dev

# Docker
.PHONY: up
up: create-dev-env
	@docker compose up --build -d

.PHONY: down
down:
	@docker compose down -v

.PHONY: create-dev-env
create-dev-env:
	@test -e .env || cp .env.example .env

# CI/CD
.PHONY: lint
lint:
	@cfn-lint stacks/**/*.yaml

.PHONY: build
build: $(services)
	@for c in $^; do $(MAKE) build -C $$c; done

.PHONY: deploy
deploy: lint build deploy-artifacts-bucket deploy-reverse-proxy

.PHONY: deploy-artifacts-bucket
deploy-artifacts-bucket:
	@aws cloudformation deploy --stack-name $(env)-reverse-proxy-artifacts \
    		--template-file stacks/artifacts-bucket.yaml \
    		--capabilities CAPABILITY_NAMED_IAM

.PHONY: deploy-reverse-proxy
deploy-reverse-proxy:
	@aws s3 cp ./reverseproxy/_dist/reverseproxy-$(version) s3://$(shell aws cloudformation describe-stacks --stack-name $(env)-reverse-proxy-artifacts --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text)/reverseproxy-$(version)
	@aws cloudformation deploy --stack-name $(env)-reverse-proxy \
			--template-file stacks/redhat/reverse-proxy.yaml \
			--parameter-overrides InstanceAMI=$(shell aws ec2 describe-images --owners 309956199498 --filters Name=name,Values=RHEL-8.6.0_HVM-*-x86_64-2-Hourly2-GP2 --query 'sort_by(Images,&CreationDate)[-1].ImageId') \
			ArtifactsBucket=$(env)-reverse-proxy-artifacts-bucket-name \
			ReverseProxyS3Key=reverseproxy-$(version) \
			--capabilities CAPABILITY_NAMED_IAM
