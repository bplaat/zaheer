# I still don't understand Make :( so I use this garbage...
# This build script is written for mingw suite on 64-bit Windows

name="korasm"
version="0.1.0"
platform="x86_64"

if [ "$1" == "clean" ]; then
    rm -r target

elif [ "$1" == "release" ]; then
    mkdir -p target/release

    for file in src/*.c; do
        gcc -Os -Iinclude -c $file -o target/release/$(basename $file .c).o
    done

    rm -f target/release/$name-v$version-$platform.exe

    gcc -s $(find target/release -name *.o) -static -o target/release/$name-v$version-$platform.exe

    rm -r target/release/*.o

else
    mkdir -p target/debug

    for file in src/*.c; do
        object="target/debug/$(basename $file .c).o"
        if [[ $file -nt $object ]]; then
            gcc -DDEBUG -Wall -Wextra -Wpedantic --std=c99 -Iinclude -c $file -o $object
        fi
    done

    rm -f target/debug/$name-v$version-$platform-debug.exe

    gcc $(find target/debug -name *.o) -o target/debug/$name-v$version-$platform-debug.exe

    ./target/debug/$name-v$version-$platform-debug.exe examples/hello.asm
fi
