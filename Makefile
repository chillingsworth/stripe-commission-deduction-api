ifneq (,$(wildcard ./.env))
    include .env
    export
endif

cloudformation-template=file://stack-template.yml

create-stack:
	@read -p "Enter New AWS Stack Name:" stack; \
	aws cloudformation create-stack --stack-name \
	$$stack --template-body $(cloudformation-template); \
	echo STACK_NAME=$$stack >> .env;

update-stack:
	@aws cloudformation update-stack --stack-name ${STACK_NAME} --template-body $(cloudformation-template);

delete-stack:
	@aws cloudformation delete-stack --stack-name ${STACK_NAME}