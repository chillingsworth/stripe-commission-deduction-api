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

configure:
	@echo "#Stripe API Commission Project Configuration#"; \
    echo "##Enter desired infrastructure variable names in the following prompts##"; \
    echo "------------------------------------------------------------------------"; \
	read -p "Enter Stripe API Key:" stripe_api_key; \
	echo STRIPE_API_KEY=$$stripe_api_key  >> .env; \
	read -p "Enter AWS Stack Name:" stack; \
	echo STACK_NAME=$$stack  >> .env; \
	read -p "Enter AWS Stack S3 Bucket Name:" bucket_name; \
	echo BUCKET_NAME=$$bucket_name  >> .env; \
	read -p "Enter RDS Database Name:" rds_name; \
	echo RDS_NAME=$$rds_name  >> .env; \
	echo DB_NAME=stripedb  >> .env; \
	read -p "Enter MySQL DB Username:" db_username; \
	echo DB_USERNAME=$$db_username  >> .env; \
	read -p "Enter MySQL DB Username Password:" db_password; \
	echo DB_PASSWORD=$$db_password  >> .env; \

create-stack: load-env
	@aws cloudformation create-stack --stack-name \
	${STACK_NAME} --template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME};

update-stack:
	@aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

delete-stack:
	@aws cloudformation delete-stack --stack-name ${STACK_NAME}; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

zip-lambda:
	@rm -r ./endpoint-lambda/*.zip; \
	zip -FSr ./endpoint-lambda/index.zip ./endpoint-lambda/index.js;

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
	@mysql --host=${RDS_ENDPOINT} \
	--user=${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME}

get-db-url:
	@echo RDS_ENDPOINT=$$(aws rds describe-db-instances \
    --filters "Name=engine,Values=mysql" "Name=db-instance-id,Values=${RDS_NAME}" \
    --query "*[].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,MasterUsername]" \
    | jq -r '.[][1]';) >> .env

configure-db: get-db-url
	@echo ${DB_USERNAME}; \
    echo ${DB_PASSWORD}; \
    echo ${RDS_ENDPOINT}; \
    echo ${DB_NAME};
	mysql -u ${DB_USERNAME} -p${DB_PASSWORD} -h ${RDS_ENDPOINT} ${DB_NAME} < "./configure-db.sql"

create-code-bucket:
	@aws s3api create-bucket --bucket ${BUCKET_NAME} --region us-east-1

package-deps:
	@mkdir -p ./build/aws-layer/python/lib/python3.9/site-packages; \
	cp requirements.txt ./build/; \
    cd ./build; \
    pip3 install -r requirements.txt --target aws-layer/python/lib/python3.9/site-packages; \
    cd ./aws-layer; \
    zip -r9 lambda-layer.zip .; \
	aws s3 --region us-east-1 cp lambda-layer.zip s3://${BUCKET_NAME}

package-lambda:
	@cd ./lambda/hook; \
	zip -r9 lambda-hook.zip .; \
	aws s3 cp lambda-hook.zip s3://${BUCKET_NAME}/

set-lambda-env:
	@aws lambda update-function-configuration --function-name lambda-hook --environment Variables="{DB_NAME=${DB_NAME}, \
	STRIPE_API_KEY=${STRIPE_API_KEY}, DB_USERNAME=${DB_USERNAME}, DB_PASSWORD=${DB_PASSWORD}, RDS_ENDPOINT=${RDS_ENDPOINT}}"

ifneq (,$(wildcard ./.env))
    include .env
    export
endif
