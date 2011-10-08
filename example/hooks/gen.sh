#!/bin/sh

../../coeus -i hooks.coeus --hook Coeus::Visual::Trace --hook 'Coeus::Visual::DotMapper FILE=output.dot' > trace 2>&1
dot -Tepdf -oconf.pdf output.dot
