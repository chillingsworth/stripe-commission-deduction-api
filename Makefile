create-stack:
	@read -p "Enter New AWS Stack Name:" stack; \
	aws cloudformation create-stack --stack-name \
	$$stack --template-body file://stack-template.yml; \
	echo STACK_NAME=$$stack >> .env;