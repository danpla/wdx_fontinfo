#!/bin/sh

mkdir -v units_tmp

case `uname -m` in
    *64) EXT="wdx64";;
    *) EXT="wdx";;
esac

fpc src/fontinfo_wdx.pas @compile.cfg -o./fontinfo."${EXT}"
