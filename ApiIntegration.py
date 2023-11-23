
import requests
import json
import uuid
import logging

import re # testing only

log = logging.getLogger()
log.setLevel(logging.DEBUG)

# base_url = 'https://qfr09kyla1.execute-api.us-east-1.amazonaws.com/Raghav'
# base_url = 'https://wuouc8h0d4.execute-api.us-east-1.amazonaws.com/dev'
base_url = 'https://api.science-at-scale.io/api161752live'

def updateBaseUrl(value):
    if value is not None:
        global base_url
        base_url = value

def startActivityJob(id,**kwargs):
    """initiate processing for a StepFunction activity using its inputs
    """
    output = {
        'vsrWorkerId': id
    }
    logger = kwargs.get('log',None)

    activityName = kwargs.get('activityName',None)
    if activityName:
        output['activityName'] = activityName

    regionCode = kwargs.get('regionCode',None)
    if regionCode:
        output['regionCode'] = regionCode

    headers = { 'Accept': 'application/json'}
    token = kwargs.get('pingToken',None)
    if token:
        headers['Authorization'] = 'bearer ' + token

    try:
        response = requests.get(base_url + '/scripting',
                                headers = headers,
                                params = output)
        response.raise_for_status()

        if logger:
            logger(str(response))

        # @TODO: this is broken for some reason - figure it out
        # Problems here are due to an error response returning an object
        # directly instead of a stringified version of data.  We are currently
        # only coding for the non-error case.
        task = response.json()
        if type(task).__name__ == 'str':
            task = json.loads(task)

        # if logger:
        #     logger(task)

        output.update({
            'taskToken': task.get('token',None),
            'taskInput': task.get('input',None)
        })

    except requests.exceptions.RequestException as e:
        output.update({'error': e})

    return(output)

def finishActivityJob(id,taskToken,status,output,**kwargs):
    """finalize processing for a StepFunction using its status and sending its outputs
    """
    result = None
    logger = kwargs.get('log',None)

    headers = { 'Content-Type': 'application/json'}
    token = kwargs.get('pingToken',None)
    if token:
        headers['Authorization'] = 'bearer ' + token

    if logger:
        logger('job ' + id + ' sending outputs with: ' + base_url + '/scripting')
        # logger('   status: ' + status + ', ping: ' + token)
        logger('   results: ' + json.dumps(output))

    try:
        response = requests.put(base_url + '/scripting',
                                headers = headers,
                                params = {
                                    'vsrWorkerId': id,
                                    'status': status
                                },
                                data = json.dumps({
                                  'token': taskToken,
                                  'output': output
                                }))
        response.raise_for_status()

    except requests.exceptions.RequestException as e:
        result = e

    return result

def testIntegration(params):
    # Extract a string version of the status path that reached us.
    jobStatus = params.get('status','fail')
    log.debug('testIntegration - executing with {}'.format(jobStatus))
    print('testIntegration - executing with {}'.format(jobStatus))

    vsrWorkerId = 'vsr-worker-' + str(uuid.uuid4())
    print('testIntegration - worker Id: {}'.format(vsrWorkerId))

    output = {
        'jobStatus': jobStatus,
        'jobInputs': {
            'message': params.get('result','no message')
        }
    }

    job = startActivityJob(vsrWorkerId)
    output.update(job)
    print('testIntegration - start result: {}'.format(job))

    if not 'error' in job:
        output.update({
            'jobOutputs': {
                'result': params.get('message','a broken prescription')
            }
        })

        result = finishActivityJob(vsrWorkerId,output['taskToken'],jobStatus,output)
        print('testIntegration - completion result: {}'.format(result))
        if result:
            output.update({'error': result})

    log.debug('testIntegration - returning with {}'.format(output))
    # pat = re.compile('.*error.*')
    # if not pat.match(output):
    if not 'error' in output:
        return {
            'statusCode': 202,
            'body': json.dumps({'message': params.get('result','a broken prescription')})
        }
    else:
        return {
            'statusCode': 500,
            'body': json.dumps(output)
        }

if __name__ == "__main__":
    log.debug('test StepFunction integration')
    result = testIntegration({
        "status": 'pass',
        "message": 'this is the prescription generation activity',
        "result": 'this is the result of generating a prescription',
        "activity": 'vsr-dev-prescription-activity'
    })

    log.debug('testIntegration - returning with {}'.format(result))
