# hints file for dos/djgpp v2.xx
# Original by Laszlo Molnar <molnarl@cdata.tvnet.hu>

# 971015 - archname changed from 'djgpp' to 'dos-djgpp'
# 971210 - threads support

archname='dos-djgpp'
archobjs='djgpp.o'
path_sep=\;
startsh="#! /bin/sh"

cc='gcc'
ld='gcc'
usrinc="$DJDIR/include"

libpth="$DJDIR/lib"
libc="$libpth/libc.a"

so='none'
usedl='n'

firstmakefile='GNUmakefile'
exe_ext='.exe'

randbits=31
lns='cp'

usenm='true'

d_link='undef'      # these are empty functions in libc.a
d_symlink='undef'
d_fork='undef'
d_pipe='undef'

startperl='#!perl'

case "X$optimize" in
  X)
	optimize="-O2 -malign-loops=2 -malign-jumps=2 -malign-functions=2"
	;;
esac
ldflags='-s'
usemymalloc='n'
timetype='time_t'

prefix=$DJDIR
privlib=$prefix/lib/perl5
archlib=$privlib
sitelib=$privlib/site
sitearch=$sitelib

eagain='EAGAIN'
rd_nodata='-1'

