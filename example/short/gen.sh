#!/bin/sh

for i in datacenter.coeus step1.coeus step2.coeus step3.coeus; do 
    dir=`basename $i .coeus`
    mkdir -p $dir
    echo "Running $i ..."
    ../../coeus -i $i --hook Coeus::Visual::Trace --hook 'Coeus::Visual::DotMapper FILE=output.dot' > $dir/trace 2>&1
    echo "Generating configuration PDF..."
    dot -Tepdf -o$dir/conf.pdf output.dot
done

echo "Creating delta traces"
for i in step*.coeus; do
    dir=`basename $i .coeus`
    rm $dir/delta
    touch $dir/delta
    diff datacenter/trace $dir/trace | patch $dir/delta
done

rm output.dot
