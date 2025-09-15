import boto3
import datetime
import json
import os
import time
from zoneinfo import ZoneInfo

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    http_method = event.get('httpMethod')
    if http_method == 'POST':
        # Handle POST request
        return handle_post(event)
    elif http_method == 'GET':
        # Handle GET request
        return handle_get(event)
    else:
        return {
            'statusCode': 405,
            'body': 'Method Not Allowed'
        }

def handle_post(event):
    apikey = event['headers'].get('apikey')
    if apikey != 'thisismyKey':
        return {
            'statusCode': 403,
            'body': 'Forbidden'
        }
    try:
        body = json.loads(event['body'])
        artist = body['artist']
        title = body['title']
        duration = int(body['duration'])
        timestamp = int(datetime.datetime.utcnow().timestamp())
        ttl = int(time.time()) + (2 * 24 * 60 * 60)  # Set TTL to 2 days from now
        item = {
            'pk': 'playlist',
            'timestamp': timestamp,
            'artist': artist,
            'title': title,
            'duration': duration,
            'ttl': ttl
        }
        table.put_item(Item=item)
        return {
            'statusCode': 200,
            'body': 'Item added successfully'
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'body': str(e)
        }

def handle_get(event):
    try:
        response = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('pk').eq('playlist'),
            ScanIndexForward=False,
            Limit=5
        )
        items = response['Items']
        json_content = generate_json(items)
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'access-control-allow-origin': '*',
            },
            'body': json_content
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }

def generate_json(items):
    data = []
    for item in items:
        # Convert Decimal to int for timestamp and duration
        timestamp = int(item['timestamp']) if hasattr(item['timestamp'], 'to_integral_value') else item['timestamp']
        duration = int(item['duration']) if hasattr(item['duration'], 'to_integral_value') else item['duration']
        
        timestamp_dt = datetime.datetime.fromtimestamp(timestamp).astimezone(ZoneInfo("America/New_York"))
        minutes, seconds = divmod(duration, 60)
        
        myDictObj = {
            "when": timestamp_dt.strftime("%I:%M%p %m/%d/%Y"),
            "timeDatetime": timestamp_dt.strftime("%Y-%m-%dT%H:%M:%S"),
            "artist": item['artist'],
            "title": item['title'],
            "length": f"{minutes}:{seconds:02d}",
        }
        data.append(myDictObj)
    
    # Use a custom JSON encoder to handle Decimal types
    class DecimalEncoder(json.JSONEncoder):
        def default(self, obj):
            if hasattr(obj, 'to_integral_value'):
                return int(obj) if obj % 1 == 0 else float(obj)
            return super(DecimalEncoder, self).default(obj)
    
    return json.dumps(data, cls=DecimalEncoder)
