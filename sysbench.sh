#! /bin/bash
export DEBIAN_FRONTEND=noninteractive 
apt-get update; apt-get install sysbench mysql-server -y -q
mysql -u root -e 'create database test;';


FLAVOR=$1

RESULT_DIR=$(mktemp -d)
CPU_COUNT=$(cat /proc/cpuinfo  | grep "^processor" | wc -l)

MAX_PRIMES=200000
TEST_TIMEOUT=240
OLTP_ROWS_NUM=1000000
FILE_SIZE=40G



sysbench --test=oltp --oltp-table-size=$OLTP_ROWS_NUM --mysql-db=test --mysql-user=root prepare


function cpu_prime {
    THREAD_COUNT=$1
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${THREAD_COUNT}.txt"

    COMMAND="sysbench --max-time=$TEST_TIMEOUT --cpu-max-prime=$MAX_PRIMES --test=cpu --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]} THREAD_COUNT=$1 MAX_PRIMES=$MAX_PRIMES" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}


function oltp {
    THREAD_COUNT=$1
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${THREAD_COUNT}.txt"
   
    COMMAND="sysbench --test=oltp --oltp-table-size=$OLTP_ROWS_NUM --mysql-db=test --mysql-user=root --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]} THREAD_COUNT=$1 OLTP_ROW_NUM=$OLTP_ROWS_NUM" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}


function io_rndrd {
    THREAD_COUNT=$1
    BLOCK_SIZE=$2
    TEST_DIR=$3
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${TEST_DIR}.${BLOCK_SIZE}.${THREAD_COUNT}.txt"

    COMMAND="sysbench --test=fileio --file-total-size=$FILE_SIZE --file-test-mode=rndrd --max-time=$TEST_TIMEOUT --max-requests=0 --file-block-size=$BLOCK_SIZE --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]}-${TEST_DIR} THREAD_COUNT=$1 BLOCK_SIZE=$2 TEST_DIR=$3" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}

function io_rndwr {
    THREAD_COUNT=$1
    BLOCK_SIZE=$2
    TEST_DIR=$3
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${TEST_DIR}.${BLOCK_SIZE}.${THREAD_COUNT}.txt"

    COMMAND="sysbench --test=fileio --file-total-size=$FILE_SIZE --file-test-mode=rndwr --max-time=$TEST_TIMEOUT --max-requests=0 --file-block-size=$BLOCK_SIZE --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]}-${TEST_DIR} THREAD_COUNT=$1 BLOCK_SIZE=$2 TEST_DIR=$3" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}

function io_seqwr {
    THREAD_COUNT=$1
    BLOCK_SIZE=$2
    TEST_DIR=$3
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${TEST_DIR}.${BLOCK_SIZE}.${THREAD_COUNT}.txt"

    COMMAND="sysbench --test=fileio --file-total-size=$FILE_SIZE --file-test-mode=seqwr --max-time=$TEST_TIMEOUT --max-requests=0 --file-block-size=$BLOCK_SIZE --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]}-${TEST_DIR} THREAD_COUNT=$1 BLOCK_SIZE=$2 TEST_DIR=$3" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}

function io_seqrd {
    THREAD_COUNT=$1
    BLOCK_SIZE=$2
    TEST_DIR=$3
    RESULT_FILE="$RESULT_DIR/${FUNCNAME[0]}.${TEST_DIR}.${BLOCK_SIZE}.${THREAD_COUNT}.txt"

    COMMAND="sysbench --test=fileio --file-total-size=$FILE_SIZE --file-test-mode=seqrd --max-time=$TEST_TIMEOUT --max-requests=0 --file-block-size=$BLOCK_SIZE --num-threads=$THREAD_COUNT run"
    echo $COMMAND
    echo "# $COMMAND" > $RESULT_FILE
    echo "# ${FUNCNAME[0]}-${TEST_DIR} THREAD_COUNT=$1 BLOCK_SIZE=$2 TEST_DIR=$3" >> $RESULT_FILE
    $COMMAND >> $RESULT_FILE
    echo "flavor: $FLAVOR" >> $RESULT_FILE
}


dest=$HOME/sb_files
    mkdir -p $dest
    pushd $dest
    sysbench --test=fileio --file-total-size=$FILE_SIZE prepare

    for tc in 1 2
    do
    	cpu_prime $tc
    	oltp $tc
    	for bs in 1K 4K 8K 64K
    	do
    		io_rndrd $tc $bs root
    		io_rndwr $tc $bs root 
    		io_seqrd $tc $bs root 
    		io_seqwr $tc $bs root
    	done
    done

    popd
    rm -rf $dest

if (mount | grep "/dev/vdb on /mnt")
then
    dest=/mnt/sb_files
        mkdir -p $dest
        pushd $dest
        sysbench --test=fileio --file-total-size=$FILE_SIZE prepare
    
        for tc in 1 2
        do
        	for bs in 1K 4K 8K 64K
        	do
        		io_rndrd $tc $bs ephemeral
        		io_rndwr $tc $bs ephemeral 
        		io_seqrd $tc $bs ephemeral 
        		io_seqwr $tc $bs ephemeral
        	done
        done
    
        popd
        rm -rf $dest
fi

python sysbench_parse.py $RESULT_DIR > sb_result.json

