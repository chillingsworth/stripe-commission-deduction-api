import json
import boto3
import logging
import json
import stripe
import mysql.connector
import os

class DBWrapper:
    def __init__(self, host, user, password, db_name):
        self.mydb = mysql.connector.connect(
        host=host,
        user=user,
        password=password)

        self.db_name = db_name
        self.mycursor = self.mydb.cursor()

    def get_customer_id(self, customer_address, customer_name):
        query = "SELECT exDB.customers.idcustomers FROM exDB.customers \
                WHERE exDB.customers.address = " + "'" + customer_address + "'" + \
                " AND exDB.customers.name = " + "'" + customer_name + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def get_customer_stripe_account(self, customer_id):
        query = "SELECT exDB.customers.stripe_account_id FROM exDB.customers \
                WHERE exDB.customers.idcustomers = " + "'" + customer_id + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def create_transfer_transaction(self, customer_id, status='TRANSFER_SUCCESSFUL'):
        query = "INSERT INTO exDB.transactions (customer_fk, event_type) VALUES (" + \
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

def lambda_handler(event, context):
    
    stripe.api_key = os.environ['STRIPE_API_KEY']

    logging.getLogger().setLevel(logging.INFO)

    ##Unpack payment_intent object
    payment_intent = json.loads(event['body'])['data']['object']
    logging.info(payment_intent)

    db = DBWrapper(host=os.environ['RDS_ENDPOINT'],
            user=os.environ['DB_USERNAME'],
            password=os.environ['DB_PASSWORD'],
            db_name=os.environ['DB_NAME'])


    if payment_intent['object'] == 'payment_intent' and payment_intent['status'] == 'succeeded':
    
        logging.info('Payment Intent')
    
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
            
            if client_info == '(created by Stripe CLI)':
                client_addr = '111 silverstream road'
                client_name = 'joes java'
            else:
                client_addr = client_info.split(' - ')[1].lower()
                client_name = client_info.split(' - ')[2].lower()
                logging.info(client_addr)
                logging.info(client_name)
            
            customer_id = DBWrapper().get_customer_id(client_addr, client_name)[0][0]
            customer_stripe_id =  DBWrapper().get_customer_stripe_account(str(customer_id))[0][0]
            
            logging.info(customer_id)
            logging.info(customer_stripe_id)
    
            try:
                result = stripe.Transfer.create(
                   amount=1,
                   currency="usd",
                   destination=customer_stripe_id,
                   transfer_group="ORDER_x",
                 )
            
                logging.info(result)
                DBWrapper().create_transfer_transaction(str(customer_id))
            
            except Exception as ex:
                logging.error(ex)
                DBWrapper().create_transfer_transaction(str(customer_id), 'TRANSFER_FAILURE')
            
        except Exception as ex:
            logging.error(ex)
 
    return {
        'statusCode': 200,
        'body': json.dumps(payment_intent)
    }

