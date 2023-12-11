#!/usr/bin/env python3

import subprocess
import json
import uuid
import time
import csv
import sys
import os
import os.path
import logging

# S3 access to data
import boto3
import botocore

# For converting from PlanA format to the expected format
import shapely.wkt as wkt
from shapely.geometry import Point

# To get and put the input and output data
import ApiIntegration as api

# Enable diagnostic information
debug = True

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
logger.name = 'run-engine'

s3 = boto3.client('s3')

default_stage        = 'dev'
default_commit       = 'none'
default_tmp_bucket = 'bayer.vsr-np.use1.loc360.scratch-space'
default_perm_bucket = 'bayer.vsr-np.use1.loc360.perm-space'

# Fewest number of label rows we will process (including header)
MinLabelRows         = 4

# Set these at container build time
stage                = os.getenv('STAGE',default_stage)

if stage == 'prod':
    default_tmp_bucket = 'bayer.vsr-prod.use1.loc360.scratch-space'
    default_perm_bucket = 'bayer.vsr-prod.use1.loc360.perm-space'

commit               = os.getenv('COMMIT',default_commit)
tmp_bucket           = os.getenv('TMP_BUCKET',default_tmp_bucket)
perm_bucket          = os.getenv('PERM_BUCKET',default_perm_bucket)

bucket_prefix        = stage

localtmpdir          = '/vsr/tmp/'

yieldpotentialfile   = 'yieldpotential.csv'

pointsfile           = 'eclayer.csv'
pointdatafilename    = 'ecpoints.csv'
pointdatafields      = ['longitude','latitude','label']

tablefile            = 'GxExT.csv'
globaltablefile      = 'globaltable.csv'
prescriptionfile     = 'prescription.xml'
metadatafile         = 'prescription.json'
ratedatafile         = 'rates.csv'
griddatafile         = 'grid.csv'
configfile           = 'pipeline-config.json'
seasonconfigfile     = 'season-config.json'
ecconfigfile         = 'ec-config.json'
scoringconfigfile    = 'scoring-config.json'

prescription_command = '/vsr/pipeline/ECDriver.r'

vsrWorkerId = 'vsr-worker-' + str(uuid.uuid4())
logger('job ' + vsrWorkerId + ' starting')

taskToken = None
vsrRunId  = None

def generateScript(inputs):
    r""" manage execution of the R script to generate a prescription
    """

    # Validate that the required keys are present

    logger('job ' + vsrWorkerId + ' started')
    # logger("These are the inputs to DSUB "+ json.dumps(inputs))

    usedColumns = ['vsrRunId',
                   'gathered',
                   'locationdata',
                   'validated',
                   'irrigation',
                   'rowWidthinches',
                   'growingSeason']
    if not all(k in inputs for k in usedColumns):
        missing = [ x for x in usedColumns if x not in inputs ]
        raise RuntimeError('job ' + vsrWorkerId
                           + ' did not recieve required inputs: '
                           + ','.join(missing))

    runid = inputs['vsrRunId']
    logger('run ' + runid + ' running as job ' + vsrWorkerId + ' with required columns found')

    # S3 temp location for this job
    jobs3path = bucket_prefix + '/logs/' + runid + '/'

    # Extract input data

    # These inputs MUST be present.
    dataRegion           = None
    cropCycleCode        = None
    enableGlobalScoring  = None
    try:
        dataRegion           = inputs['locationdata']['regionCode']
        fieldZone            = inputs['locationdata']['mpz']
        boundsType           = inputs['locationdata']['boundstype']
        fieldZone            = inputs['locationdata']['mpz']
        cropCycleCode        = inputs['locationdata']['cropCycleCode']
        fieldBoundary        = inputs['locationdata']['wkt']
        enableGlobalScoring  = inputs['validated']['enable-global-scoring']
        rate_source          = inputs['gathered'][0][0]['source']
        gxmxt_table          = inputs['gathered'][0][0]['gxmxt_table_version']
        gormxt_table         = inputs['gathered'][0][0]['gormxt_table_version']
        ec_table             = inputs['gathered'][0][0]['ec_table_name']

    except KeyError as e:
        raise RuntimeError('job ' + vsrWorkerId + ' could not extract data from input: {}'.format(e))

    # These inputs are ok to not be present.
    disableBagAdjustment = None
    try:
        disableBagAdjustment = inputs['validated']['disable-bag-adjustment']

    except KeyError as e:
        pass

    highUpperBound = None
    if 'highupperbound' in inputs['locationdata']:
        highUpperBound = inputs['locationdata']['highupperbound']

    planType = None
    if 'planType' in inputs:
        planType = inputs['planType']

    # Default model information to use informed rates
    modelType    = 'informed'
    modelSize    = rate_source
    modelVersion = {
      "GxT":   gormxt_table,
      "MxT":   gormxt_table,
      "GxMxT": gxmxt_table
    }.get(rate_source,'default')

    # Grab the global scoring configuration information
    scoringVersion = None
    scoringModel   = None
    scoringConfigLocation = localtmpdir + scoringconfigfile
    with open(scoringConfigLocation,'r') as f:
        scoringConfig  = json.load(f)
        try:
            scoringVersion = scoringConfig['version']
            scoringModel   = scoringConfig[stage][dataRegion]['model']
        except KeyError as e:
            # It is ok to not have a scoring model, we just won't score the data
            logger('job ' + vsrWorkerId + ' could not extract data from scoring configuration: {}'.format(e))

    # Grab the season configuration information
    modelSeason = None
    seasonConfigLocation = localtmpdir + seasonconfigfile
    with open(seasonConfigLocation,'r',encoding='utf-8') as f:
        seasonConfig = json.load(f)
        if cropCycleCode in seasonConfig:
            modelSeason = seasonConfig[ cropCycleCode ]

    # Check for soil data
    soilData = None
    yield_to = localtmpdir + yieldpotentialfile
    if 'soildata' in inputs['gathered'][1]:
        if 'yieldpotential' in inputs['gathered'][1]['soildata'][1]['output']:
            soilData = True
            yieldpotential = inputs['gathered'][1]['soildata'][1]['output']['yieldpotential']
            s3.download_file(tmp_bucket,yieldpotential,yield_to)
            logger('run ' + runid + ' yield potential data at ' + yield_to)

    # Check for the presence of label data
    labelTypes     = None
    labelFileName  = None
    labelTableName = None
    try:
        if 'name' in inputs['gathered'][1] and inputs['gathered'][1]['name'] == 'get-ec-layer':
            if inputs['gathered'][1] and inputs['gathered'][1]['rowcount'] > MinLabelRows:
                labelTypes = 'planA'
                labelFileName = jobs3path + pointsfile
                labelTableName = ec_table
                logger('run ' + runid + ' working with plan A labels')

        if 'soildata' in inputs['gathered'][1]:
            if inputs['gathered'][1]['soildata'][0]['rows'] > MinLabelRows:
                labelTypes = 'global'
                labelFileName = inputs['gathered'][1]['soildata'][0]['labelfile']
                labelTableName = ec_table
                logger('run ' + runid + ' working with global labels')

    except KeyError:
        raise RuntimeError('job ' + vsrWorkerId + ' could not determine EC information')

    # Check for presence of EC data
    pointdatafile = localtmpdir + pointdatafilename
    table_to      = localtmpdir + tablefile
    if labelTypes and labelTableName:
        # Extract the EC table from S3
        tablepath  = bucket_prefix + '/data/tables/' + dataRegion + '/'
        table_from = tablepath + labelTableName
        logger('run ' + runid + ' copying ' + table_from + ' to ' + table_to)
        s3.download_file(perm_bucket,table_from,table_to)
        logger('run ' + runid + ' lookup table at ' + table_to)

        if labelTypes == "global":
            modelType    = labelTypes
            modelSize    = scoringModel
            modelVersion = scoringVersion

            # Subset the table for the current zone and season if we are using a global model
            global_table = localtmpdir + globaltablefile
            os.rename(table_to,global_table)
            with open(global_table,newline='') as tfile:
                reader = csv.DictReader(tfile)
                tablecols = reader.fieldnames

                with open(table_to,'w',newline='') as outfile:
                    writer = csv.DictWriter(outfile,fieldnames=tablecols)
                    writer.writeheader()
                    for line in reader:
                        if modelSeason \
                        and modelSeason != line['PlantingWindowStart']:
                            continue
                        elif 'zone' in line \
                        and line['zone'] != fieldZone:
                            continue

                        writer.writerow(line)

        # Locate the EC data points data
        points_to   = localtmpdir + pointdatafilename
        logger('run ' + runid + ' copying ' + labelFileName + ' to ' + points_to)
        s3.download_file(tmp_bucket,labelFileName,points_to)
        logger('run ' + runid + ' ec data at ' + points_to)

        if labelTypes == 'planA':
            # Grab the EC configuration information
            ecConfigLocation = localtmpdir + ecconfigfile
            with open(ecConfigLocation,'r') as f:
                ecConfig     = json.load(f)
                modelType    = labelTypes
                modelSize    = ecConfig[stage]
                modelVersion = ecConfig['version']
                modelColumn  = ecConfig['ec-plana'][modelSize]

            # Convert EC data from Plan A format
            plana_file = localtmpdir + pointsfile
            os.rename(points_to,plana_file)
            with open(plana_file,newline='') as infile:
                reader = csv.DictReader(infile)

                with open(points_to,'w',newline='') as outfile:
                    writer = csv.DictWriter(outfile,fieldnames=pointdatafields)
                    writer.writeheader()
                    for line in reader:
                        location = wkt.loads(line['geom'])

                        current = {}
                        current['longitude'] = location.x
                        current['latitude']  = location.y
                        current['label']     = line[modelColumn]
                        writer.writerow(current)

    # Extract the seeding rate(s)
    width = inputs["rowWidthinches"]
    rate      = None
    lowerrate = None
    upperrate = None
    try:
        rate      = inputs['gathered'][0][0]['rate']
        lowerrate = inputs['gathered'][0][0]['dry']
        upperrate = inputs['gathered'][0][0]['wet']

    except KeyError:
        raise RuntimeError('run ' + runid + ' could not determine seeding rate(s)')

    if(rate == None):
        raise RuntimeError('run ' + runid + ' no available informed seeding rate')

    # Extract the female parent name
    mother = None
    try:
        mother = inputs["gathered"][0][0]['productdata']['lookupName']

    except KeyError:
        raise RuntimeError('run ' + runid + ' could not determine female parent name')

    # Process the hybrid name for use as a lookup key
    mother = mother.split('-')[0]

    logger('run ' + runid + ' rate, width, and parent extracted')

    # Local input locations
    configLocation    = localtmpdir + configfile

    # Local output locations
    prescription_data = localtmpdir + prescriptionfile
    prescription_meta = localtmpdir + metadatafile
    rates_file        = localtmpdir + ratedatafile
    grid_file         = localtmpdir + griddatafile

    logger('run ' + runid + ' output to ' + prescription_data)
    logger('run ' + runid + ' metadata to ' + prescription_meta)

    # Create the R script command line
    # Accepted arguments:
    #    --config          string  -- local file location of configuration file
    #    --wkt             string  -- field boundary WKT
    #    --region          string  -- field location region code
    #    --product         string  -- product Id used for table lookup
    #    --irrigated       boolean -- field is irrigated
    #    --table           string  -- local file location of lookup table
    #    --labels          string  -- local file location of labeled point data
    #    --yieldpotential  string  -- local file location of yield potential data
    #    --planA           boolean -- labels are planA labels
    #    --lowerrate       integer -- td-argentina model lower rate
    #    --static          integer -- informed static rate to use if needed
    #    --upperrate       integer -- td-argentina model upper rate
    #    --rowwidth        integer -- width of planting rows
    #    --output          string  -- local output filename
    #    --boundstype      string  -- type of bounds limiting to perform (linear,area)
    #    --highupperbound  string  -- alternate upper bound for France
    #    --plantype        string  -- crop plan type, default='commercial'
    #    --globalscoring   boolean -- use global scoring models if possible
    #    --nobagadjustment boolean -- disable bag count to be the same for static and variable
    #    --metaout         string  -- local metadata output filename
    #    --ratesout        string  -- local rate data output filename
    args = [
        prescription_command,
        '--config',         configLocation,
        '--wkt',            fieldBoundary,
        '--region',         dataRegion,
        '--product',        mother,
        '--static',         str(rate),
        '--rowwidth',       str(width),
        '--boundstype',     boundsType,
        '--output',         prescription_data,
        '--metaout',        prescription_meta
    ]

    if labelTypes and labelTableName:
        args.extend(['--table',table_to])
        args.extend(['--labels',pointdatafile])
        if labelTypes == 'planA':
            args.append('--planA')

    if soilData:
        args.extend(['--yieldpotential',yield_to])
        args.extend(['--lowerrate',str(lowerrate)])
        args.extend(['--upperrate',str(upperrate)])

    if highUpperBound:
        args.extend(['--highupperbound',str(highUpperBound)])

    if planType:
        args.extend(['--plantype',planType])

    if enableGlobalScoring:
        args.append('--globalscoring')

    if disableBagAdjustment:
        args.append('--nobagadjustment')

    if inputs["irrigation"]:
        args.append('--irrigated')

    if debug == True:
        args.extend(['--ratesout',rates_file])
        args.extend(['--gridout',grid_file])

    logger('run ' + runid + ' command: ' + '\n'.join(args))

    # Run the R script to generate the prescription
    try:
        script = subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        logger('R Script return: {}'.format(script.returncode))
        logger('R Script result: {}'.format(script.stdout))

    except subprocess.CalledProcessError as e:
        raise RuntimeError('R script failed: {}'.format(e.output))

    # Remote output location
    prescription_to = jobs3path + prescriptionfile
    metadata_to     = jobs3path + metadatafile
    ratedata_to     = jobs3path + ratedatafile
    griddata_to     = jobs3path + griddatafile

    # use boto3 to upload the prescription.xml results to S3
    s3.upload_file(prescription_data,tmp_bucket,prescription_to,ExtraArgs={"ServerSideEncryption": 'AES256'})
    logger('run ' + runid + ' result uploaded to s3://' + tmp_bucket + '/' + prescription_to)

    # use boto3 to upload the prescription.json results to S3
    s3.upload_file(prescription_meta,tmp_bucket,metadata_to,ExtraArgs={"ServerSideEncryption": 'AES256'})
    logger('run ' + runid + ' metadata uploaded to s3://' + tmp_bucket + '/' + metadata_to)

    if debug == True:
        if os.path.isfile(rates_file):
            # use boto3 to upload the rates.csv results to S3
            s3.upload_file(rates_file,tmp_bucket,ratedata_to,ExtraArgs={"ServerSideEncryption": 'AES256'})
            logger('run ' + runid + ' rate data uploaded to s3://' + tmp_bucket + '/' + ratedata_to)

        if os.path.isfile(grid_file):
            # use boto3 to upload the grid.csv results to S3
            s3.upload_file(grid_file,tmp_bucket,griddata_to,ExtraArgs={"ServerSideEncryption": 'AES256'})
            logger('run ' + runid + ' grid data uploaded to s3://' + tmp_bucket + '/' + griddata_to)

    # call task complete with results metadata
    #  output data is in JSON format in the metadata output: prescription.json
    outputs = None
    with open(prescription_meta) as file:
        outputs = json.load(file)
        outputs['prescription'] = prescription_to
        outputs['status'] = 'pass'

        source = outputs['rateSource']
        if source == 'label-lookup':
            outputs['model_version'] = modelType + '.' + modelSize + '.' + modelVersion
        elif source == 'td-model':
            outputs['model_version'] = source + '.' + scoringVersion
        elif source == 'informed':
            outputs['model_version'] = source + '.' + modelSize + '.' + modelVersion

        return outputs

    raise RuntimeError('run ' + runid + ' unable to find processing results')

def runEngine():
    r""" Wrapper to start and manage execution of the R prescription generator
    """
    logger('job ' + vsrWorkerId + ' running with scripting endpoint: ' + base_url)
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
            # logger('run ' + vsrRunId + ' starting job with token: ' + taskToken)

            # marshal the inputs and fire up the processing
            return generateScript(job['taskInput'])

        else:
            raise RuntimeError('run ' + vsrRunId + ' no inputs found')

    except RuntimeError as e:
        msg = 'ERROR - {}'.format(e)
        logger(msg)
        return({'error': msg, 'status': 'fail'})

    except:
        msg = 'ERROR - Unexpected error: {}'.format(str(sys.exc_info()))
        logger(msg)
        return({'error': msg, 'status': 'fail'})

# Run the prescription generator
outputs = runEngine()
outputs['activityName'] = activityName
outputs['regionCode']   = regionCode
outputs['vsrRunId']     = vsrRunId

# Call task complete
if taskToken is not None:
    logger('run ' + vsrRunId + ' finishing job with status: ' + outputs['status'])
    result = api.finishActivityJob(vsrWorkerId,taskToken,outputs['status'],outputs,pingToken = pingToken, log = logger)
    if result:
        logger('ERROR: {}'.format(result))
    else:
        logger('processing complete with: {}'.format(outputs))
else:
    logger('no task identified to finish processing for')
