import json
import boto3
import logging
import json
import stripe
import mysql.connector


class DBWrapper:
    def __init__(self):
        self.mydb = mysql.connector.connect(
        host="stripe-commission-db.c17tbmhfjkr0.us-east-1.rds.amazonaws.com",
        user="admin",
        password="beatnik-ashore-dutch")

        self.mycursor = self.mydb.cursor()

    def get_customer_id(self, customer_address, customer_name):
        query = "SELECT transactions.customers.idcustomers FROM transactions.customers \
                WHERE transactions.customers.address = " + "'" + customer_address + "'" + \
                " AND transactions.customers.name = " + "'" + customer_name + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def get_customer_stripe_account(self, customer_id):
        query = "SELECT transactions.customers.stripe_account_id FROM transactions.customers \
                WHERE transactions.customers.idcustomers = " + "'" + customer_id + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def create_transfer_transaction(self, customer_id, status='TRANSFER_SUCCESSFUL'):
        query = "INSERT INTO transactions.transactions (customer_fk, event_type) VALUES (" + \
                str(customer_id) + ", '" + status + "')"

        self.mycursor.execute(query)

        return self.mydb.commit()
        
    def test(self):
        customer_id = DBWrapper().get_customer_id('111 silverstream road', 'joes java')[0][0]
        print(customer_id)
        customer_stripe_id =  DBWrapper().get_customer_stripe_account(str(customer_id))[0][0]
        print(customer_stripe_id)
        create_transaction_result =  DBWrapper().create_transfer_transaction(str(customer_id))
        print(create_transaction_result) 


logging.getLogger().setLevel(logging.INFO)

def lambda_handler(event, context):
    
    ##Unpack payment_intent object
    
    payment_intent = json.loads(event['body'])['data']['object']
    logging.info(payment_intent)
    
    if payment_intent['object'] == 'payment_intent' and payment_intent['status'] == 'succeeded':
    
        logging.info(payment_intent['object'])
        logging.info(payment_intent['status'])
        logging.info(payment_intent['amount_received'])
        
        ####

        COMMISSION = .01
        amount_received = payment_intent['amount_received']
        transfer_amount = amount_received - (amount_received * COMMISSION)
        logging.info(transfer_amount)
    
        try:
            client_info = payment_intent['description']
            logging.info(client_info)
            client_addr = client_info.split(' - ')[1].lower()
            client_name = client_info.split(' - ')[2].lower()
            logging.info(client_addr)
            logging.info(client_name)
            
            customer_id = DBWrapper().get_customer_id(client_addr, client_name)[0][0]
            customer_stripe_id =  DBWrapper().get_customer_stripe_account(str(customer_id))[0][0]
            
            logging.info(customer_id)
            logging.info(customer_stripe_id)
            
            stripe.api_key = ''
    
            try:
                result = stripe.Transfer.create(
                   amount=1,
                   currency="usd",
                   destination=customer_stripe_id,
                   transfer_group="ORDER_95",
                 )
            
                logging.info(result)
                DBWrapper().create_transfer_transaction(str(customer_id))
            
            except Exception as ex:
                logging.error(ex)
                DBWrapper().create_transfer_transaction(str(customer_id), 'TRANSFER_FAILURE')
            
        except Exception as ex:
            logging.error(ex)
        ####
        
        # sqs_client = boto3.client("sqs", region_name="us-east-1")
        # response = sqs_client.send_message(
        #     QueueUrl="https://sqs.us-east-1.amazonaws.com/484906661071/stripe-api.fifo",
        #     MessageBody=json.dumps(payment_intent),
        #     MessageGroupId='586474de88e03'
        # )
        # stripe.api_key = "sk_test_51JtVtBLGGx9YIBhrqpm9HgAEhEUe6omNNMOFKREvM9HD2Sz5PbEqaeZoDt9s934wFR98AZ8dNGa9DcClYVBT2ceW00AWzDegch"
        # result = stripe.Transfer.create(
        #   amount=1,
        #   currency="usd",
        #   destination="acct_1K1ZebPw7IujTWEe",
        #   transfer_group="ORDER_95",
        # )
        # logging.info(result)
                

    # TODO implement
    return {
        'statusCode': 200,
        'body': json.dumps(payment_intent)
    }

