SHELL := /bin/bash

.ONESHELL:

cloudformation-template=file://template.yml

load-env:
    ifneq (,$(wildcard ./.env))
        include .env
        export
    endif

docker-build:
	@docker build -t stripe .

docker-run: docker-build
	@docker run -it -v ~/.aws:/root/.aws -v ${PWD}:/root/code/ stripe

configure:
	@echo "#Stripe API Commission Project Configuration#"; \
    echo "##Enter desired infrastructure variable names in the following prompts##"; \
    echo "------------------------------------------------------------------------"; \
	read -p "Enter AWS CLI Profile Name:" aws_profile_name; \
	echo AWS_PROFILE=$$aws_profile_name  >> .env; \
	read -p "Enter AWS CLI Profile Region:" aws_region; \
	echo AWS_REGION=$$aws_region  >> .env; \
	read -p "Enter API Stage Name:" api_stage_name; \
	echo API_STAGE_NAME=$$api_stage_name  >> .env; \
	read -p "Enter API Name:" api_name; \
	echo API_NAME=$$api_name  >> .env; \
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
	echo DB_PASSWORD=$$db_password  >> .env;
	
create-code-bucket: load-env
	@aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} \
	--create-bucket-configuration LocationConstraint=${AWS_REGION}

package-deps: load-env
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

create-stack: create-code-bucket package-lambda load-env
	@aws cloudformation create-stack --stack-name \
	${STACK_NAME} --template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=ApiGatewayStageName,ParameterValue=${API_STAGE_NAME} \
	ParameterKey=ApiGatewayName,ParameterValue=${API_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	ParameterKey=RDSName,ParameterValue=${RDS_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME};

update-stack: package-lambda load-env
	@aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-body $(cloudformation-template) \
	--parameters ParameterKey=DatabaseName,ParameterValue=${DB_NAME} \
	ParameterKey=ApiGatewayStageName,ParameterValue=${API_STAGE_NAME} \
	ParameterKey=ApiGatewayName,ParameterValue=${API_NAME} \
	ParameterKey=DBMasterUsername,ParameterValue=${DB_USERNAME} \
	ParameterKey=DBMasterUserPassword,ParameterValue=${DB_PASSWORD} \
	ParameterKey=S3BucketName,ParameterValue=${BUCKET_NAME} \
	ParameterKey=RDSName,ParameterValue=${RDS_NAME} \
	--capabilities CAPABILITY_IAM; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

get-db-url:
	@echo RDS_ENDPOINT=$$(aws rds describe-db-instances \
    --filters "Name=engine,Values=mysql" "Name=db-instance-id,Values=${RDS_NAME}" \
    --query "*[].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,MasterUsername]" \
    | jq -r '.[][1]';) >> .env; \
	export RDS_ENDPOINT;

configure-db: get-db-url
	@echo ${DB_USERNAME}; \
    echo ${DB_PASSWORD}; \
    echo ${RDS_ENDPOINT}; \
    echo ${DB_NAME};
	mysql -u ${DB_USERNAME} -p${DB_PASSWORD} -h ${RDS_ENDPOINT} ${DB_NAME} < "./configure-db.sql"

set-lambda-env:
	@aws lambda update-function-configuration --function-name lambda-hook --environment Variables="{DB_NAME=${DB_NAME}, \
	STRIPE_API_KEY=${STRIPE_API_KEY}, DB_USERNAME=${DB_USERNAME}, DB_PASSWORD=${DB_PASSWORD}, RDS_ENDPOINT=${RDS_ENDPOINT}}"

api-test:
	@echo $(shell aws apigateway get-rest-apis --profile ${AWS_PROFILE} \
	--query 'items[?name==`my-api`][id][0]' --output text);

get-api-id:
	@echo API_ID=$(shell aws apigateway get-rest-apis --profile ${AWS_PROFILE} \
	--query 'items[?name==`${API_NAME}`][id][0]' --output text)  >> .env;

compose-api-endpoint:
	@echo API_ENDPOINT=https://${API_ID}\
	.execute-api.${AWS_REGION}.amazonaws.com/\
	${API_STAGE_NAME}/  >> .env;

deploy: create-stack load-env configure-db set-lambda-env \
get-api-id load-env compose-api-endpoint
	@echo "Deployment is Live";

connect-db: get-db-url
	@mysql --host=${RDS_ENDPOINT} \
	--user=${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME}

delete-stack:
	@aws s3 rm s3://${BUCKET_NAME} --recursive; \
	aws s3api delete-bucket --bucket ${BUCKET_NAME}; \
	aws cloudformation delete-stack --stack-name ${STACK_NAME}; \
	aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME};

clean:
	@rm .env;
