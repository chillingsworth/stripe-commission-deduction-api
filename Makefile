SHELL := /bin/bash

cloudformation-template=file://template.yml

clean:
	@rm -f ${KEYPAIR_NAME};
	@rm .env;

load-env:
    ifneq (,$(wildcard ./.env))
        include .env
        export
    endif

create-ec2-key-pair: install-requirements
    ifeq (,$(wildcard ./*.pem))
		@read -p "Enter PEM Key Name:" keyname;\
		echo KEYPAIR_NAME=$$keyname >> .env; \
		aws ec2 create-key-pair --key-name $$keyname \
		| jq -r ".KeyMaterial" > $$keyname.pem; \
		chmod 400 $$keyname.pem;
    endif

create-stack: load-env
    ifeq (,$(KEYPAIR_NAME))
	    @echo "Run 'make create-ec2-key-pair' first";
		exit 1;
    endif
    ifeq (,${STACK_NAME})
	    @read -p "Enter New AWS Stack Name:" stack; \
        aws cloudformation create-stack --stack-name \
        $$stack --template-body $(cloudformation-template) \
		--parameters ParameterKey="KeyName",ParameterValue=${KEYPAIR_NAME}; \
        echo STACK_NAME=$$stack >> .env; \
		aws cloudformation wait stack-create-complete --stack-name $$stack;

    endif

update-stack:
	@aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-body $(cloudformation-template) \
	--parameters ParameterKey="KeyName",ParameterValue=${KEYPAIR_NAME}; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

delete-stack:
	@aws cloudformation delete-stack --stack-name ${STACK_NAME}

zip-endpoint-lambda:
	zip -FSr ./endpoint-lambda/endpoint-lambda.zip ./endpoint-lambda -x ./endpoint-lambda/.\*

set-aws-uname: set-env
	@read -p "Enter AWS Username:" uname; \
	echo AWS_ROLE_UNAME=$$uname >> .env;

install-requirements:
	@sudo apt-get install --assume-yes jq

instances = aws ec2 describe-instances --query \
	"Reservations[*].Instances[*].{PublicIP:PublicIpAddress,Type:InstanceType,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" \
	--filters "Name=tag:aws:cloudformation:stack-name, Values="${STACK_NAME} \
	"Name=instance-state-name, Values=running"

instance-ip = $(call instances) | jq '[.[][] | select(.PublicIP != null)] | .[].PublicIP'

connect-ec2:
	@ssh -i ${KEYPAIR_NAME}.pem ubuntu@$(shell $(call instance-ip))

connect-db:
	@mysql --host=stripe-stack-auroracluster-l7la0owbkiok.cluster-c17tbmhfjkr0.us-east-1.rds.amazonaws.com \
	--user=example --password=password exDB

ifneq (,$(wildcard ./.env))
    include .env
    export
endif
