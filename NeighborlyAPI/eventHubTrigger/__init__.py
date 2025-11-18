import json
import logging
import azure.functions as func


def main(event: func.EventGridEvent):
    """
    This function is triggered by Event Grid events.
    It logs the event details when new advertisements are created.
    """
    
    logging.info('EventGrid trigger function started')
    
    result = json.dumps({
        'id': event.id,
        'data': event.get_json(),
        'topic': event.topic,
        'subject': event.subject,
        'event_type': event.event_type,
    })

    logging.info('Python EventGrid trigger processed an event: %s', result)
    
    # Log specific event data
    event_data = event.get_json()
    if event_data:
        logging.info('Event Data: %s', json.dumps(event_data))
    
    logging.info('EventGrid trigger function completed')



