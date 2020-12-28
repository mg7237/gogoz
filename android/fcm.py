import requests
import json

serverToken = 'AAAAI7pXKXg:APA91bHm7jcjeHbAMKcygJwJ94I7XYepm-kaCXQNOhqmckf4g0hkMCfRS9EVLH8VPncwvqVM8Pvh_uIJaonBO_-qcRZa9rYYOMvS4p8cL2TcbDt2FwiKgaD1PEwzhQp2OPWSzrOyGCaZ'
deviceToken = 'dshU4w5nTguM8TnQBrYTQ5:APA91bFsdx7n7tctNbqD5fXoJPE8i-T1jgXfjgiV2HE_vtiaINz5JwPytTTZ8nKm-t3doNyXC-b73x82xt1nXYaKfdDtvxtfLLUTOm-CDk5mXqI1kcVqflYMuDX-v4xYYTmQ5kACEdTO'

headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=' + serverToken,
      }

body = {
          'notification': {'title': 'Sending push form python script',
                            'body': 'New Message'
                            },
          'to':
              deviceToken,
          'priority': 'high',
        #   'data': dataPayLoad,
        }
response = requests.post("https://fcm.googleapis.com/fcm/send",headers = headers, data=json.dumps(body))
print(response.status_code)

print(response.json())
