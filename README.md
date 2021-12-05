# stripe-commission-deduction-api
API and cloud infrastructure for deducting commission from Stripe account deposits and forwarding the remainder to customer Stripe accounts

##Deploying
1. Run ```make package-deps```
2. Run ```make create-code-bucket```
3. RUN ```make package-lambda```
3. Run ```make create-stack```
4. Run ```make configure-db```

##Testing
stripe listen --forward-to https://9nb6768bo4.execute-api.us-east-1.amazonaws.com/call/
stripe trigger payment_intent.succeeded
