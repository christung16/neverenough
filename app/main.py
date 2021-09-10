from flask import Flask, request, Response
import json
import requests

app = Flask(__name__)
request_attention = False
message_id_for_card = ""
debug = False

# meeting Room ID
roomID = "<Webex Team Room ID>"
message = ""
# token of the BOT
token = 'Bearer ' + '<Webex Chat Bot API Token>'

headers = {
  'Authorization': token,
  'Content-Type': 'application/json'
}
payload={"roomId":"", "text":""}
payload["roomId"] = roomID

# API Token for terraform
terraform_headers = {
  'Content-Type': 'application/vnd.api+json',
  'Authorization': 'Bearer ' + '<Terraform Cloud API Token>'
}

@app.route('/webhook', methods=['POST'])
def respond():
    request_attention = False
    webmsg = request.json
    print(webmsg)
    webex =  'targetUrl' in webmsg.keys()
    terraform = 'run_id' in webmsg.keys()
    if terraform:
       run_id = webmsg['run_id']
       trigger = webmsg['notifications'][0]['trigger']
       workspace = webmsg['workspace_name']
       workspace_id = webmsg['workspace_id']
       run_url = webmsg['run_url']
       run_created_at = webmsg['run_created_at']
       run_created_by = webmsg['run_created_by']
       if trigger == 'run:needs_attention':
          request_attention = True
          message = "Run ID: **" + run_id + "** needs your attention to confirm"
       else:
          message = request.json['notifications'][0]['message']

    if webex:
       # message = "Chat Bot Message received"
       source = webmsg['name']
       if source == "Message-to-Heroku":
          message_id = webmsg['data']['id']
          payload={}
          url = "https://webexapis.com/v1/messages/"+message_id
          response = requests.request("GET", url, headers=headers, data=payload)
          # extract the message content from the BOT and change it to all upper case
          message = json.loads(response.text)['text'].upper()
          print (message)
       if source == "WebexCard-to-HeroKu":
          print ("Webex action received")
          message_id = webmsg['data']['id']
          approver_id = webmsg['actorId']
          payload={}
          url = "https://webexapis.com/v1/attachment/actions/"+message_id
          response = requests.request("GET", url, headers=headers, data=payload)
          inputs = json.loads(response.text)["inputs"]
          print (inputs)
          decision = inputs['ACTION']
          run_id = inputs['RUN_ID']
          run_url = inputs['RUN_URL']
          print (decision)
          print (run_id)
          print (run_url)
          if decision == "DENY":
             decision = "DENIED"
             discard_run(run_id)
          if decision == "APPROVE":
             decision = "APPROVED"
             approve_run(run_id)
          deleteMessage(json.loads(response.text)['messageId'])
          postnotice_webex(decision, run_url, approver_id)
    if terraform and trigger == 'run:needs_attention':
       # Debug echo message ...
       payload={"roomId":"", "text":""}
       payload["roomId"] = roomID
       payload["text"] = message
       url = "https://webexapis.com/v1/messages/"
       if debug:
          response = requests.request("POST", url, headers=headers, data=json.dumps(payload))
          print (response.text)
       if request_attention:
          postmsgcard_webex(run_id, run_url, run_created_at, run_created_by)
       request_attention = False
    #print ("Run: %s ==> %s" % (run_id, trigger))
    return Response(status=200)

def discard_run(run_id):
    url = "https://app.terraform.io/api/v2/runs/" + run_id + "/actions/discard"
    payload={}
    response = requests.request("POST", url, headers=terraform_headers, data=payload)

    print(response.text)
    return (response.text)

def approve_run(run_id):
    url = "https://app.terraform.io/api/v2/runs/" + run_id + "/actions/apply"
    payload={}
    response = requests.request("POST", url, headers=terraform_headers, data=payload)

    print(response.text)
    return (response.text)

def postnotice_webex(decision, run_url, approver_id):
    approver_email, approver_name = getApproverDetails(approver_id)
    url = "https://webexapis.com/v1/messages"

    payload = {
      "roomId": "",
      "markdown": "Decision is made",
      "attachments": [
            {
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": {
                                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                                "type": "AdaptiveCard",
                                "version": "1.2",
                                "body": [
                                            {
                                                "type": "ColumnSet",
                                                "columns": [
                                                    {
                                                        "type": "Column",
                                                        "width": 2,
                                                        "items": [
                                                            {
                                                                "type": "TextBlock",
                                                                "text": "Powered by Cisco Webex Teams"
                                                            },
                                                            {
                                                                "type": "TextBlock",
                                                                "text": "APPROVED",
                                                                "weight": "Bolder",
                                                                "size": "ExtraLarge",
                                                                "spacing": "None"
                                                            },
                                                            {
                                                                "type": "TextBlock",
                                                                "text": "★★★☆",
                                                                "isSubtle": True,
                                                                "spacing": "None"
                                                            },
                                                            {
                                                                "type": "TextBlock",
                                                                "text": "",
                                                                "size": "Small",
                                                                "wrap": True
                                                            }
                                                            ]
                                                    }
                                                ]
                                            }
                                        ],
                                "actions": [
                                                {
                                                    "type": "Action.OpenUrl",
                                                    "title": "",
                                                    "url": ""
                                                }
                                            ]
                            }
            }
        ]
    }

    payload['roomId'] = roomID
    payload['attachments'][0]['content']['body'][0]['columns'][0]['items'][1]['text'] = decision
    payload['attachments'][0]['content']['body'][0]['columns'][0]['items'][2]['text'] = "by " +  approver_name + "(" + approver_email + ")"
    payload['attachments'][0]['content']['body'][0]['columns'][0]['items'][3]['text'] = run_url
    payload['attachments'][0]['content']['actions'][0]['url'] = run_url
    print (decision)
    if decision == "APPROVED":
       payload['attachments'][0]['content']['actions'][0]['title'] = "Approval Details"
    if decision == "DENIED":
       payload['attachments'][0]['content']['actions'][0]['title'] = "Denial Details"

    #payload['attachments'][0]['content'][2]['columns'][1]['items'][0]['text']="Jul 31st, 2021"
    print (payload)
    response = requests.request("POST", url, headers=headers, data=json.dumps(payload))

    if response.status_code == 200:
       message_id_for_card = json.loads(response.text)['id']
    print ("\n")
    print (message_id_for_card)
    print (response.text)

    return Response(status=response.status_code)

def postmsgcard_webex(run_id, run_url, run_created_at, run_created_by):
    request_attention = False
    url = "https://webexapis.com/v1/messages"

    payload = {
      "roomId": "",
      "markdown": "Approval Request",
      "attachments": [
            {
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": {
                    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                    "type": "AdaptiveCard",
                    "body": [
                        {
                            "type": "ColumnSet",
                            "columns": [
                                {
                                    "type": "Column",
                                    "items": [
                                        {
                                            "type": "Image",
                                            "style": "Person",
                                            "url": "https://developer.webex.com/images/webex-teams-logo.png",
                                            "size": "Medium",
                                            "height": "50px"
                                        }
                                        ],
                                    "width": "auto"
                                },
                                {
                                    "type": "Column",
                                    "items": [
                                        {
                                            "type": "TextBlock",
                                            "text": "Powered by Cisco Webex Teams",
                                            "weight": "Lighter",
                                            "color": "Accent"
                                        },
                                        {
                                            "type": "TextBlock",
                                            "weight": "Bolder",
                                            "text": "!! CHANGE REQUEST RECEIVED !!",
                                            "wrap": True,
                                            "color": "Light",
                                            "size": "Large",
                                            "spacing": "Small"
                                        }
                                        ],
                                    "width": "stretch"
                                }
                                ]
                            },
                            {
                                "type": "ColumnSet",
                                "columns": [
                                    {
                                        "type": "Column",
                                        "width": 35,
                                        "items": [
                                            {
                                                "type": "TextBlock",
                                                "text": "Received Date/Time:",
                                                "color": "Light"
                                            },
                                            {
                                                "type": "TextBlock",
                                                "text": "Requested by:",
                                                "weight": "Lighter",
                                                "color": "Light",
                                                "spacing": "Small"
                                            },
                                            {
                                                "type": "TextBlock",
                                                "text": "Details URL:",
                                                "weight": "Lighter",
                                                "color": "Light",
                                                "spacing": "Small"
                                            }
                                            ]
                                    },
                                    {
                                        "type": "Column",
                                        "width": 65,
                                        "items": [
                                            {
                                                "type": "TextBlock",
                                                "text": "Aug 6, 2019",
                                                "color": "Light"
                                            },
                                            {
                                                "type": "TextBlock",
                                                "text": "Requester name",
                                                "color": "Light",
                                                "weight": "Lighter",
                                                "spacing": "Small"
                                            },
                                            {
                                                "type": "TextBlock",
                                                "text": "Mac, Windows, Web",
                                                "weight": "Lighter",
                                                "color": "Light",
                                                "spacing": "Small",
                                                "wrap": True
                                            }
                                            ]
                                    }
                                ],
                                "spacing": "Padding",
                                "horizontalAlignment": "Center"
                            },
                            {
                                "type": "TextBlock",
                                "text": "Please review and reply:"
                            },
                            {
                                "type": "ActionSet",
                                "actions": [
                                    {
                                        "type": "Action.OpenUrl",
                                        "title": "Details",
                                        "url": ""
                                    },
                                    {
                                        "type": "Action.Submit",
                                        "title": "APPROVE",
                                        "data": {
                                            "ACTION": "APPROVE",
                                            "RUN_ID": "",
                                            "RUN_URL": ""
                                                }
                                    },
                                    {
                                        "type": "Action.Submit",
                                        "title": "DENY",
                                        "data": {
                                            "ACTION": "DENY",
                                            "RUN_ID": "",
                                            "RUN_URL": ""
                                                }
                                    }
                                    ],
                                "spacing": "None"
                            }
                        ],
                        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                        "version": "1.2"
                    }
            }
            ]
    }


    payload['roomId'] = roomID
    payload['attachments'][0]['content']['body'][1]['columns'][1]['items'][0]['text'] = run_created_at
    payload['attachments'][0]['content']['body'][1]['columns'][1]['items'][1]['text'] = run_created_by
    payload['attachments'][0]['content']['body'][1]['columns'][1]['items'][2]['text'] = run_url
    payload['attachments'][0]['content']['body'][3]['actions'][0]['url'] = run_url
    payload['attachments'][0]['content']['body'][3]['actions'][1]['data']['RUN_ID'] = run_id
    payload['attachments'][0]['content']['body'][3]['actions'][2]['data']['RUN_ID'] = run_id
    payload['attachments'][0]['content']['body'][3]['actions'][1]['data']['RUN_URL'] = run_url
    payload['attachments'][0]['content']['body'][3]['actions'][2]['data']['RUN_URL'] = run_url

    #payload['attachments'][0]['content'][2]['columns'][1]['items'][0]['text']="Jul 31st, 2021"
    print (payload)
    response = requests.request("POST", url, headers=headers, data=json.dumps(payload))

    if response.status_code == 200:
       message_id_for_card = json.loads(response.text)['id']
    print ("\n")
    print (message_id_for_card)
    print (response.text)


    return Response(status=response.status_code)

def deleteMessage(message_id):
    payload={}
    url = "https://webexapis.com/v1/messages/" + message_id
    response = requests.request("DELETE", url, headers=headers, data=json.dumps(payload))
    return Response(status=response.status_code)

def getApproverDetails(person_id):
    payload={}
    approver_name = ""
    approver_email = ""
    url = "https://webexapis.com/v1/people/" + person_id
    response = requests.request("GET", url, headers=headers, data=json.dumps(payload))
    if response.status_code == 200:
       result = json.loads(response.text)
       approver_email = result['emails'][0]
       approver_name = result['displayName']
    return approver_email, approver_name
