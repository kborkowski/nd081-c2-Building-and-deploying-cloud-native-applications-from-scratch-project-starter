import azure.functions as func
import pymongo
import os
import json
import logging
from datetime import datetime
from azure.eventgrid import EventGridPublisherClient, EventGridEvent
from azure.core.credentials import AzureKeyCredential

def main(req: func.HttpRequest) -> func.HttpResponse:

    request = req.get_json()

    if request:
        try:
            url = os.environ.get('MyDbConnection')
            client = pymongo.MongoClient(url)
            database = client['neighborlydb']
            collection = database['advertisements']

            rec_id1 = collection.insert_one(eval(request))
            
            # Publish event to Event Grid
            try:
                eventgrid_endpoint = os.environ.get('EventGridTopicEndpoint')
                eventgrid_key = os.environ.get('EventGridTopicKey')
                
                if eventgrid_endpoint and eventgrid_key:
                    credential = AzureKeyCredential(eventgrid_key)
                    client = EventGridPublisherClient(eventgrid_endpoint, credential)
                    
                    event = EventGridEvent(
                        event_type="Neighborly.Advertisement.Created",
                        data={
                            "id": str(rec_id1.inserted_id),
                            "title": request.get('title', 'New Advertisement'),
                            "description": request.get('description', ''),
                            "city": request.get('city', ''),
                            "created_at": datetime.utcnow().isoformat()
                        },
                        subject="advertisement/created",
                        data_version="1.0"
                    )
                    
                    client.send(event)
                    logging.info(f"Event published to Event Grid for advertisement {rec_id1.inserted_id}")
                else:
                    logging.warning("Event Grid credentials not configured")
                    
            except Exception as e:
                logging.error(f"Failed to publish event to Event Grid: {str(e)}")
                # Continue execution even if event publishing fails

            return func.HttpResponse(req.get_body())

        except ValueError:
            print("could not connect to mongodb")
            return func.HttpResponse('Could not connect to mongodb', status_code=500)

    else:
        return func.HttpResponse(
            "Please pass name in the body",
            status_code=400
        )