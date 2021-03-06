#!/bin/bash
make -C build/
if [ $? -eq 0 ]; then
 echo 'OK Compile'
else
 echo 'FAIL Transform'
 exit    
fi 


if [ $# -eq 0 ]
  then
    echo "Bitcode file need to be supplied"
    exit 1
fi

UTILS_PATH=/home/sip/self-checksumming/build/lib/libUtils.so
INPUT_DEP_PATH=/usr/local/lib/
OH_PATH=/home/sip/sip-oblivious-hashing
OH_LIB=$OH_PATH/build/lib
bitcode=$1
assert_list=$2
input=$3

# compiling external libraries to bitcodes
#clang++-3.9 $OH_PATH/assertions/asserts.cpp -fno-use-cxa-atexit -std=c++0x -c -emit-llvm -o $OH_PATH/assertions/asserts.bc
#clang-3.9 $OH_PATH/hashes/hash.c -c -fno-use-cxa-atexit -emit-llvm -o $OH_PATH/hashes/hash.bc
#clang++-3.9 $OH_PATH/assertions/logs.cpp -fno-use-cxa-atexit -std=c++0x -c -emit-llvm -o $OH_PATH/assertions/logs.bc
clang-6.0 $OH_PATH/assertions/response.c -c -fno-use-cxa-atexit -emit-llvm -o $OH_PATH/assertions/response.bc
 
# Running hash insertion pass
#if [ $# -eq 2 ] 
#  then
#    echo "Assert file list is supplied"
#    opt-3.9 -load $INPUT_DEP_PATH/libInputDependency.so -load $UTILS_PATH -load  $OH_LIB/liboblivious-hashing.so $bitcode -oh-insert -num-hash 1 -skip 'hash' -dump-oh-stat="oh.stats" -assert-functions $assert_list -o out.bc
#else
    echo "No assert file is supplied.."
    #echo "opt-3.9 -load $INPUT_DEP_PATH/libInputDependency.so -load $UTILS_PATH -load $OH_LIB/liboblivious-hashing.so $bitcode -oh-insert -num-hash 1 -skip 'hash' -dump-oh-stat="oh.stats" -o out.bc"
    #exit
    opt-6.0 -load $INPUT_DEP_PATH/libInputDependency.so -load /usr/local/lib/libLLVMdg.so -load $UTILS_PATH -load $OH_LIB/liboblivious-hashing.so -load $INPUT_DEP_PATH/libTransforms.so $bitcode -strip-debug -unreachableblockelim -globaldce -dependency-stats -dependency-stats-file='dependency.stats' -lib-config=/home/sip/input-dependency-analyzer/library_configs/tetris_library_config.json  -oh-insert -short-range-oh -num-hash 1 -skip 'hash' -dump-oh-stat="oh.stats" -o out.bc

#fi

if [ $? -eq 0 ]; then
            echo 'OK Transform'
else
            echo 'FAIL Transform'
            exit    
fi 

LIB_FILE=()

llc out.bc
g++ -std=c++0x -c -rdynamic out.s -o out.o

g++ -fPIC -std=c++11 -g -rdynamic -c ${OH_PATH}/assertions/response.cpp -o ${OH_PATH}/assertions/oh_rtlib.o
LIB_FILES+=( "${OH_PATH}/assertions/oh_rtlib.o" )

g++ -std=c++11 -g -rdynamic -Wall -fPIC -shared -Wl,-soname,${OH_PATH}/assertions/libsrtlib.so -o "${OH_PATH}/assertions/librtlib.so" -lncurses -lm -lssl -lcrypto -pthread ${LIB_FILES[@]}

g++ -std=c++11 -g -rdynamic out.o -o out -L${OH_PATH}/assertions/ -lrtlib -lncurses -lm -lssl -lcrypto -pthread

# Linking with external libraries
#llvm-link-3.9 out.bc $OH_PATH/assertions/response.bc -o out.bc

# intermediate precompute hashes
#clang++-3.9 -g -lncurses -rdynamic -std=c++0x out.bc -o out

export LD_PRELOAD="/home/sip/self-checksumming/hook/build/libminm.so ${OH_PATH}/assertions/librtlib.so"
echo "$LD_PRELOAD"
#
##Patch using GDB

python $OH_PATH/patcher/patchAsserts.py -b out -n out_patched -s oh.stats -d False -p "/home/sip/sip-oblivious-hashing/assertions/gdb_script_for_do_assert.txt"
echo 'Generated bianry is out_patched ...'
chmod +x out_patched
