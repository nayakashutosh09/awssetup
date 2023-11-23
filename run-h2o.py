#!/usr/bin/env python3

import subprocess
import json
import uuid
import time
import csv
import sys
import os
import logging

# S3 access to data
import boto3
import botocore

# For converting from PlanA format to the expected format
import shapely.wkt as wkt
from shapely.geometry import Point

# To get and put the input and output data
import ApiIntegration as api

# Poor mans argument parsing
pingToken = None
if len(sys.argv) > 1:
    pingToken = sys.argv[1]
base_url = 'default'
if len(sys.argv) > 2:
    base_url = sys.argv[2]
    api.updateBaseUrl(base_url)
    print('updated base URL for I/O to: ' + base_url);
activityName = None
if len(sys.argv) > 3:
    activityName = sys.argv[3]
regionCode = None
if len(sys.argv) > 4:
    regionCode = sys.argv[4]
diagnostics = False
if len(sys.argv) > 5: # Presence of the last argument is enough to turn on diagnostics
    diagnostics = True

log = logging.getLogger()
log.setLevel(logging.DEBUG)

def logger(*args):
    """ format log messages consistently
        Adds the process identifier and a timestamp to the log messages.
        The syslog+logstash mechanism does not appear to include a high
        enough resolution identifier for this job, and the timestamps do
        not appear to be at the time the log message was written.
    """
    print('%s: %s -- ' % (time.strftime("%Y-%m-%d %H:%M:%S",time.gmtime()),logger.name),*args)
logger.name = 'run-h2o-model'

s3 = boto3.client('s3')

default_stage        = 'dev'
default_tmp_bucket   = 'bayer.vsr-np.use1.loc360.scratch-space'
default_perm_bucket  = 'bayer.vsr-np.use1.loc360.perm-space'

# Set these at container build time
stage                = os.getenv('STAGE',default_stage)

if stage == 'prod':
    default_tmp_bucket = 'bayer.vsr-prod.use1.loc360.scratch-space'
    default_perm_bucket = 'bayer.vsr-prod.use1.loc360.perm-space'

tmp_bucket           = os.getenv('TMP_BUCKET',default_tmp_bucket)
perm_bucket          = os.getenv('PERM_BUCKET',default_perm_bucket)

bucket_prefix        = stage
efspath              = '/efs/' + bucket_prefix + '/models'

localtmpdir          = '/vsr/tmp'

modelfile            = 'Mod_5.0_QC5'
calibratedfile       = 'calibratedsoil.csv'
outputfile           = 'yieldpotential.csv'
regionalfile         = 'regionaldata.json'
inputcsvfile         = 'h2oinputs.csv'

# modellocation        = efspath + '/' + modelfile
modellocation        = localtmpdir + '/' + modelfile
calibratedlocation   = localtmpdir + '/' + calibratedfile
outputlocation       = localtmpdir + '/' + outputfile
regionallocation     = localtmpdir + '/' + regionalfile
inputcsvlocation     = localtmpdir + '/' + inputcsvfile

h2o_command = '/vsr/pipeline/RunH2O.R'

vsrWorkerId = 'vsr-worker-' + str(uuid.uuid4())
logger('job ' + vsrWorkerId + ' starting')

# Set and accessed as a global variable
taskToken = None
vsrRunId  = None

def runH2oModel(inputs):
    r""" manage execution of the R script to generate yield potentials
    """
    logger('job ' + vsrWorkerId + ' started')
    # logger("These are the inputs to DSUB "+ json.dumps(inputs))

    # Validate that the required keys are present
    usedColumns = ['vsrRunId',
                   'calibrateddata'] # N.B. Ok to run without regional data
    if not all(k in inputs for k in usedColumns):
        missing = [ x for x in usedColumns if x not in inputs ]
        raise RuntimeError('job ' + vsrWorkerId
                           + ' did not recieve required inputs: '
                           + ','.join(missing))

    coefficient = 3
    logger('job ' + vsrWorkerId + ' required columns found')

    # Check for presence of calibrated soil
    if 'calibrateddata' in inputs:
        soilbucket = inputs['calibrateddata']['bucket']
        soilsource = inputs['calibrateddata']['destination']

        logger('job ' + vsrWorkerId + ' copying ' + soilsource + ' to ' + calibratedlocation)

        s3.download_file(soilbucket,soilsource,calibratedlocation)
        logger('job ' + vsrWorkerId + ' calibrated soil data at ' + calibratedlocation)

    # Local output locations
    logger('job ' + vsrWorkerId + ' output to ' + outputfile)

    # Create the R script command line
    # Accepted arguments:
    #   --model'        -- local file location of H2O model
    #   --soildata      -- local file location of calibrated soil data
    #   --ratedata      -- local file location of rate output data
    #   --coefficient   -- model prediction QC coefficient to use, default='3'
    #   --auxdata       -- local file location of regional data
    #   --inputcsv      -- local CSV file with model input data
    args = [
        h2o_command,
        '--model',       modellocation,
        '--soildata',    calibratedlocation,
        '--ratedata',    outputlocation,
        '--coefficient', str(coefficient)
    ]

    if diagnostics:
        args.extend(['--inputcsv',inputcsvlocation])

    # Put the regional data into a local file for the R script to read
    if 'auxdata' in inputs:
        logger('writing ' + regionallocation + ' with ' + json.dumps(inputs['auxdata']))
        with open(regionallocation,'w') as file:
            json.dump(inputs['auxdata'],file)
        args.extend(['--auxdata',regionallocation])

    logger('job ' + vsrWorkerId + ' command: ' + '\n'.join(args))

    outputs = {
      'name': 'run-h2o-model',
      'status': 'pass'
    }

    # Run the R script to generate the prescription
    try:
        script = subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        logger('R Script return: {}'.format(script.returncode))
        logger('R Script result: {}'.format(script.stdout))

        # S3 output location
        jobs3path = bucket_prefix + '/logs/' + inputs['vsrRunId'] + '/'
        output_to = jobs3path + outputfile

        # use boto3 to upload the output results to S3
        s3.upload_file(outputlocation,tmp_bucket,output_to,ExtraArgs={"ServerSideEncryption": 'AES256'})
        logger('job ' + vsrWorkerId + ' result uploaded to ' + output_to)
        outputs['yieldpotential'] = output_to

    except subprocess.CalledProcessError as e:
        logger('model execution failed to run properly: ' + str(e.returncode))
        if e.returncode == 254:  # -2 in 8 bit 2's complement
            logger('no soil data to process, no yield potential created')
        else:
            raise RuntimeError('R script failed: {}'.format(e.output))

    return outputs

def runModel():
    r""" Wrapper to start and manage execution of the R yield potential generator
    """

    logger('job ' + vsrWorkerId + ' running with scripting endpoint: ' + base_url)
    logger('default encoding: ' + sys.getdefaultencoding())
    try:
        # call task started
        job = api.startActivityJob(vsrWorkerId,
                                   pingToken = pingToken,
                                   log = logger,
                                   activityName = activityName,
                                   regionCode = regionCode)
        # logger('job ' + vsrWorkerId + ': ' + json.dumps(job))

        global vsrRunId
        vsrRunId = job['taskInput']['vsrRunId']

        inputs = None
        if not 'error' in job:
            global taskToken
            taskToken = job['taskToken']
            # logger('job ' + vsrWorkerId + ' starting job with token: ' + taskToken)

            # marshal the inputs and fire up the processing
            return runH2oModel(job['taskInput'])

        else:
            raise RuntimeError('job ' + vsrWorkerId + ' no inputs found')

    except RuntimeError as e:
        msg = 'ERROR - {}'.format(e)
        logger(msg)
        return({'error': msg, 'status': 'fail'})

    except:
        msg = 'ERROR - Unexpected error: {}'.format(str(sys.exc_info()))
        logger(msg)
        return({'error': msg, 'status': 'fail'})

# Run the model
outputs = runModel()
outputs['activityName'] = activityName
outputs['regionCode']   = regionCode
outputs['vsrRunId']     = vsrRunId

# Call task complete
if taskToken is not None:
    logger('job ' + vsrWorkerId + ' finishing job with status: ' + outputs['status'])
    result = api.finishActivityJob(vsrWorkerId,taskToken,outputs['status'],outputs,pingToken = pingToken, log = logger)
    if result:
        logger('ERROR: {}'.format(result))
    else:
        logger('processing complete with: {}'.format(outputs))
else:
    logger('no task identified to finish processing for')
