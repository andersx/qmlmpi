#!/usr/bin/env python
import numpy as np
import sys

if len(sys.argv) != 3:
	print ('Usage: %s alphas1 alphas2' % sys.argv[0])
	exit(1)

if np.allclose(*map(np.loadtxt, sys.argv[1:])):
	print 'Ok.'
else:
	print 'Failed.'

