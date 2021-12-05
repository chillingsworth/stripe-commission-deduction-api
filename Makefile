SHELL := /bin/bash

cloudformation-template=file://template.yml

load-env:
    ifneq (,$(wildcard ./.env))
        include .env
        export
    endif

install-requirements:
	@sudo apt-get install --assume-yes jq

configure: install-requirements
	@echo "#Stripe API Commission Project Configuration#"; \
    echo "##Enter desired infrastructure variable names in the following prompts##"; \
    echo "------------------------------------------------------------------------"; \
	read -p "Enter Stripe API Key:" stripe_api_key; \
	echo STRIPE_API_KEY=$$stripe_api_key  >> .env; \
	read -p "Enter AWS Stack Name:" stack; \
	echo STACK_NAME=$$stack  >> .env; \
	read -p "Enter AWS Stack S3 Bucket Name:" bucket_name; \
	echo BUCKET_NAME=$$bucket_name  >> .env; \
	read -p "Enter AWS RDS Instance Name:" rds_name; \
	echo RDS_NAME=$$rds_name  >> .env; \
	read -p "Enter MySQL Database Name:" db_name; \
	echo DB_NAME=$$db_name  >> .env; \
	read -p "Enter MySQL DB Username:" db_username; \
	echo DB_USERNAME=$$db_username  >> .env; \
	read -p "Enter MySQL DB Username Password:" db_password; \
	echo DB_PASSWORD=$$db_password  >> .env; \

create-code-bucket: load-env
	@aws s3api create-bucket --bucket ${BUCKET_NAME} --region us-east-1

package-deps: create-code-bucket
	@mkdir -p ./build/aws-layer/python/lib/python3.9/site-packages; \
	cp requirements.txt ./build/; \
    cd ./build; \
    pip3 install -r requirements.txt --target aws-layer/python/lib/python3.9/site-packages; \
    cd ./aws-layer; \
    zip -r9 lambda-layer.zip .; \
	aws s3 --region us-east-1 cp lambda-layer.zip s3://${BUCKET_NAME}

package-lambda: package-deps
	@cd ./lambda/hook; \
	zip -r9 lambda-hook.zip .; \
	aws s3 cp lambda-hook.zip s3://${BUCKET_NAME}/;

create-stack: package-lambda
	@aws cloudformation create-stack --stack-name \
	${STACK_NAME} --template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	ParameterKey=RDSName,ParameterValue=${RDS_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME};

update-stack: package-lambda
	@aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	ParameterKey=RDSName,ParameterValue=${RDS_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

delete-stack:
	@aws cloudformation delete-stack --stack-name ${STACK_NAME}; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

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

connect-db: get-db-url
	@mysql --host=${RDS_ENDPOINT} \
	--user=${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME}

set-lambda-env:
	@aws lambda update-function-configuration --function-name lambda-hook --environment Variables="{DB_NAME=${DB_NAME}, \
	STRIPE_API_KEY=${STRIPE_API_KEY}, DB_USERNAME=${DB_USERNAME}, DB_PASSWORD=${DB_PASSWORD}, RDS_ENDPOINT=${RDS_ENDPOINT}}"

deploy: create-stack configure-db set-lambda-env
	@echo "Deployment is Live";

clean:
	@rm .env;

ifneq (,$(wildcard ./.env))
    include .env
    export
endif
