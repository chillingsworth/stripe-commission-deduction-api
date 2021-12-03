import logging

logging.getLogger().setLevel(logging.INFO)

def lambda_handler(event, context):
    logging.info("working2!")
    # TODO implement
    return {
        'statusCode': 200,
        'body': 'working'
    }
