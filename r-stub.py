#!/usr/bin/env python3

import argparse
import shutil

parser = argparse.ArgumentParser(description='R code stub')
parser.add_argument('parms',nargs='*')
args = vars(parser.parse_args())

for i, v in enumerate(args['parms']):
    print('R stub: arg{} = {}'.format(i,v))

shutil.copy('/vsr/pipeline/stub.xml',args['parms'][6])
shutil.copy('/vsr/pipeline/stub.json',args['parms'][7])

        # tablefile,
        # inputs["wkt"],
        # eclayerfile,
        # mother,
        # str(rate),
        # str(width),
        # prescription_data,
        # prescription_meta
