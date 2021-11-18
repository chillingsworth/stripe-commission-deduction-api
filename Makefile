cloudformation-template=file://template.yml

create-stack:
	@read -p "Enter New AWS Stack Name:" stack; \
	aws cloudformation create-stack --stack-name \
	$$stack --template-body $(cloudformation-template); \
	echo STACK_NAME=$$stack >> .env;

update-stack:
	@aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-body $(cloudformation-template) \
	--parameters ParameterKey="KeyName",ParameterValue=${KEYPAIR_NAME}

delete-stack:
	@aws cloudformation delete-stack --stack-name ${STACK_NAME}

zip-endpoint-lambda:
	zip -FSr ./endpoint-lambda/endpoint-lambda.zip ./endpoint-lambda -x ./endpoint-lambda/.\*

set-aws-uname: set-env
	@read -p "Enter AWS Username:" uname; \
	echo AWS_ROLE_UNAME=$$uname >> .env;

create-ec2-key-pair:
    ifeq (,$(wildcard ./*.pem))
		@read -p "Enter PEM Key Name:" keyname; \
		echo KEYPAIR_NAME=$$keyname >> .env; \
		aws ec2 create-key-pair --key-name $$keyname > $$keyname.pem
    endif
	
list-instances:
	@aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name, Values="${STACK_NAME}

ifneq (,$(wildcard ./.env))
    include .env
    export
endif
