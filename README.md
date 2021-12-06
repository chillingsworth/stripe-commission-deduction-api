# stripe-commission-deduction-api
Ready-to-use software for Web Developers who want to monetize their web services by taking a portion of their client's online ordering transactions (commission) and transferring the rest to the client's stripe account.

This configuration works with the GloriaFoods online food ordering platform and is configured to be deployed to production via Makefile to AWS.

[System Diagram](system-diagram.md)

Note: The Access Control Lists and Security Group configurations are set to be wide open so that the Web Developer can see the deployed MySQL database to observe the transaction ledger from any IP address. If you want better security, consider constraining the allowed IPs in the ACL/SGs to match your individual IP address.

## Environment Setup
1. Install Docker on your local environment
2. ```make docker-run```

**All instructions below are assumed to be executed from the command line of this running container**

## Deploy from Terminal
1. ```make configure```
* Your input is saved to a dotenv file (called .env) in the project directory
* Be sure to use the AWS CLI profile name you'd like to use. You can find this by looking in ```~/.aws/credentials```
2. ```make deploy```
* The infrastructure is live if you get a ```Deployment is Live``` message
* Deployment will take time. Give the command 10 mins or so to setup the AWS infrastructure

### Testing the Deployment from Terminal
1. ```stripe listen --forward-to https://${API_ENDPOINT}/call/```
2. ```stripe trigger payment_intent.succeeded``` (from a separate terminal window)

### Troubleshooting
1. ```make clean``` will delete the dotenv (.env) file
2. Re-deploy the app via the instructions above

## Switching from Test to Prod
1. Change the ```STRIPE_API_KEY``` value in your dotenv file to the appropriate key
2. ```make set-lambda-env```

## Teardown from Terminal
1. ```make delete-stack```
