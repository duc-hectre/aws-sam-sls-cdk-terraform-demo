import json

import boto3

# import debug tool
# import ptvsd

# ptvsd.enable_attach(address=("0.0.0.0", 3002), redirect_output=True)
# ptvsd.wait_for_attach()


def lambda_handler(event, context):
    """Sample pure Lambda function

    Parameters
    ----------
    event: dict, required
        API Gateway Lambda Proxy Input Format

        Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

    context: object, required
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
    API Gateway Lambda Proxy Output Format: dict

        Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html
    """

    # try:
    #     ip = requests.get("http://checkip.amazonaws.com/")
    # except requests.RequestException as e:
    #     # Send some context about this error to Lambda Logs
    #     print(e)

    #     raise e

    print(event)
    dynamoDb = boto3.resource('dynamodb')
    table = dynamoDb.Table("SlsHelloDbTable")

    if event["httpMethod"] == "POST":
        data = json.loads(event["body"])
        print(data)
        name = data["name"]
        existItems = table.scan()
        print(type(existItems))
        count = len(existItems['Items']) + 1
        if data:
            table.put_item(
                Item={'id': str(count), 'Name': name})
            return {
                "statusCode": 201,
                "body": json.dumps({
                    "name": name,
                    # "location": ip.text.replace("\n", "")
                }),
            }
        else:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "message": "missing name arg",
                    # "location": ip.text.replace("\n", "")
                }),
            }
    else:
        response = table.scan()
        items = response['Items'] if response else {}
        return {
            "statusCode": 200,
            "body":  json.dumps(items) if items else "",
        }
