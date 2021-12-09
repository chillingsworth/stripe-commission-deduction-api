# stripe-commission-deduction-api
Ready-to-use software for Web Developers who want to monetize their web services by taking a portion of their client's online ordering transactions (commission) and transferring the rest to the client's stripe account.

This configuration works with the GloriaFoods online food ordering platform and is configured to be deployed to production via Makefile to AWS.

[System Diagram](system-diagram.md)

Note: The Access Control Lists and Security Group configurations are set to be wide open so that the Web Developer can see the deployed MySQL database to observe the transaction ledger from any IP address. If you want better security, consider constraining the allowed IPs in the ACL/SGs to match your individual IP address.

## Setup and Run
1. Install [Docker](https://docs.docker.com/engine/install/) and [GNU Make](https://www.gnu.org/software/make/) on your local machine
    * If you get permission denied with Docker, follow the instructions to give your user access to the docker group: ```https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue```
2. The docker container copies the ~/.aws/credentials file into the container when it's run, so make sure you have credentials in that file for an IAM role with appropriate privledges
    * For more information, see [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) 
4. ```make easy-configure```
    * Checkout the default values in the .conf file and feel free to change
5. ```make docker-run```
    * This uses the values from the .env file and .conf file to create the cloudformation stack. This will take 10 mins or so to complete, so be patient.
6. ```make docker-configure-db```
    * This creates the tables in the new database along with a test client record

## Testing the Deployment from Terminal
* Requires stripe CLI. To install on Debian: 
```wget https://github.com/stripe/stripe-cli/releases/download/v1.7.8/stripe_1.7.8_linux_x86_64.tar.gz && tar -xvf stripe_1.7.8_linux_x86_64.tar.gz -C /usr/local/bin```
1. ```stripe listen --forward-to ${API_ENDPOINT}```
2. ```stripe trigger payment_intent.succeeded``` (from a separate terminal window)
    * Note that the ```stripe listen``` process will persist and cause multiple event triggering. Be sure to kill that process before starting another ```stripe listen ...``` process via command shown in step 1

## Troubleshooting
1. ```make clean``` will delete the dotenv (.env) file
2. Re-deploy the app via the instructions above
3. Be sure you have unique AWS item names in the .conf file as conflicts may arise due to stack naming rules in AWS

## Switching from Test to Prod
1. Change the ```STRIPE_API_KEY``` value in your dotenv file to the appropriate key
2. ```make set-lambda-env```

## Teardown from Terminal
1. ```make delete-stack```
