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
        customer_name = customer_name.replace("'", "''")
        query = "SELECT stripedb.customers.idcustomers FROM stripedb.customers \
                WHERE stripedb.customers.address = " + "'" + customer_address + "'" + \
                " AND stripedb.customers.name = " + "'" + customer_name + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def get_customer_stripe_account(self, customer_id):
        query = "SELECT stripedb.customers.stripe_account_id FROM stripedb.customers \
                WHERE stripedb.customers.idcustomers = " + "'" + customer_id + "'"
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult

    def create_transfer_transaction(self, customer_id, transaction_id, transfer_id, status='TRANSFER_SUCCESSFUL'):
        query = "INSERT INTO stripedb.transactions (customer_fk, event_type, stripe_hook_transaction_id, outgoing_transfer_id) VALUES (" + \
                str(customer_id) + ", '" + status + "', '" + transaction_id + "', '" + transfer_id + "')"

        self.mycursor.execute(query)

        return self.mydb.commit()
        
    def get_successful_transaction_count(self, transaction_id):
        query = "SELECT COUNT(*) FROM stripedb.transactions WHERE stripedb.transactions.stripe_hook_transaction_id = '" + \
            str(transaction_id) + "' AND stripedb.transactions.event_type = 'TRANSFER_SUCCESSFUL'"
            
        self.mycursor.execute(query)
        
        myresult = self.mycursor.fetchall()

        return myresult[0][0]

    def test(self):
        customer_id = DBWrapper().get_customer_id('111 silverstream road', 'joes java')[0][0]
        print(customer_id)
        customer_stripe_id =  DBWrapper().get_customer_stripe_account(str(customer_id))[0][0]
        print(customer_stripe_id)
        create_transaction_result =  DBWrapper().create_transfer_transaction(str(customer_id))
        print(create_transaction_result) 

def lambda_handler(event, context):
    
    COMMISSION = .01

    logging.getLogger().setLevel(logging.INFO)

    try:

        stripe.api_key = os.environ['STRIPE_API_KEY']
    
        db = DBWrapper(host=os.environ['RDS_ENDPOINT'],
            user=os.environ['DB_USERNAME'],
            password=os.environ['DB_PASSWORD'],
            db_name=os.environ['DB_NAME'])
    
        ##Unpack payment_intent object
        payment_intent = json.loads(event['body'])['data']['object']
    
        if payment_intent['object'] == 'payment_intent' and payment_intent['status'] == 'succeeded' \
            and db.get_successful_transaction_count(payment_intent['id']) == 0:
        
            logging.info('===Payment Intent Success Webhook Triggered===')
            
            logging.info('---No Transactions In DB With Id: ' + payment_intent['id'] + '. Continuing Transfer.')
            logging.info('---Unpacking Transaction Info From Webhook Body---')
            
            tx_id = payment_intent['id']
            logging.info('Incoming Transaction Id:')
            logging.info(tx_id)
    
            amount_received = payment_intent['amount_received']
            logging.info('Amount Received:')
            logging.info(amount_received)
            
            transfer_amount = int(amount_received - (amount_received * COMMISSION))
            logging.info('Amount Transferring Back to Client Account:')
            logging.info(transfer_amount)
        
            try:
                logging.info('---Unpacking Transaction Info From Webhook Body---')
    
                client_info = payment_intent['description']
                logging.info('Unparsed Client Information:')
                logging.info(client_info)
                
                ##Check API Test Case
                if client_info == '(created by Stripe CLI)':
                    logging.info('---Recieved Test API Request---')
                    client_addr = "test"
                    client_name = "tim's tea"
                else:
                    client_addr = client_info.split(' - ')[1].lower()
                    client_name = client_info.split(' - ')[2].lower()
                    logging.info('Parsed Client Information:')
                    logging.info(client_addr)
                    logging.info(client_name)
                
                logging.info('---Retrieving Client Stripe Id From Database---')
                customer = db.get_customer_id(client_addr, client_name)
                
                if len(customer) != 0:
                    customer_id = customer[0][0]
                    customer_stripe =  db.get_customer_stripe_account(str(customer_id))
                    if len(customer_stripe) != 0:
                        customer_stripe_id =  customer_stripe[0][0]
                    else:
                        customer_stripe_id = -1
                else:
                    customer_id = -1
                    customer_stripe_id = -1
                    
                logging.info('Client Database Id:')
                logging.info(customer_id)
                logging.info('Client Stripe Id:')
                logging.info(customer_stripe_id)
        
                try:
                    logging.info('---Attempting Stripe Transfer---')
    
                    result = stripe.Transfer.create(
                       amount=transfer_amount,
                       currency="usd",
                       destination=customer_stripe_id,
                       transfer_group="ORDER_x",
                     )
                    logging.info('---Transfer Success---')
                    logging.info('Transfer Result:')
                    logging.info(result)
                    
                    logging.info('Outgoing Client Transfer Id:')
                    tr_id = result['id']
                    logging.info(tr_id)
                    
                    db.create_transfer_transaction(str(customer_id), tx_id, tr_id)
                
                except Exception as ex:
                    logging.info('!!!Transfer Failure!!!')
                    logging.error(ex)
    
                    db.create_transfer_transaction(str(customer_id), tx_id, tr_id, 'TRANSFER_FAILURE')
                
            except Exception as ex:
                logging.error(ex)
     
        return {
            'statusCode': 200,
            'body': json.dumps(payment_intent)
        }
        
    except Exception as ex:
        logging.error(ex)
