BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
use warnings;
use bytes;

use Test::More ;
use ZlibTestUtils;

BEGIN {
    plan(skip_all => "oneshot needs Perl 5.005 or better - you have Perl $]" )
        if $] < 5.005 ;


    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 2462 + $extra ;

    use_ok('Compress::Zlib', 2) ;

    use_ok('IO::Compress::Gzip', qw($GzipError)) ;
    use_ok('IO::Uncompress::Gunzip', qw($GunzipError)) ;

    use_ok('IO::Compress::Deflate', qw($DeflateError)) ;
    use_ok('IO::Uncompress::Inflate', qw($InflateError)) ;

    use_ok('IO::Compress::RawDeflate', qw($RawDeflateError)) ;
    use_ok('IO::Uncompress::RawInflate', qw($RawInflateError)) ;

    use_ok('IO::Uncompress::AnyInflate', qw(anyinflate $AnyInflateError)) ;

}


# Check zlib_version and ZLIB_VERSION are the same.
is Compress::Zlib::zlib_version, ZLIB_VERSION, 
    "ZLIB_VERSION matches Compress::Zlib::zlib_version" ;



foreach my $bit ('IO::Compress::Gzip',
                 'IO::Uncompress::Gunzip',
                 'IO::Compress::Deflate',
                 'IO::Uncompress::Inflate',
                 'IO::Compress::RawDeflate',
                 'IO::Uncompress::RawInflate',
                 'IO::Uncompress::AnyInflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    title "Testing $TopType Error Cases";

    my $a;
    my $x ;

    eval { $a = $Func->(\$a => \$x, Fred => 1) ;} ;
    like $@, mkErr("^$TopType: unknown key value\\(s\\) Fred"), '  Illegal Parameters';

    eval { $a = $Func->() ;} ;
    like $@, mkErr("^$TopType: expected at least 1 parameters"), '  No Parameters';

    eval { $a = $Func->(\$x, \1) ;} ;
    like $@, mkErr("^$TopType: output buffer is read-only"), '  Output is read-only' ;

    my $in ;
    eval { $a = $Func->($in, \$x) ;} ;
    like $@, mkErr("^$TopType: input filename is undef or null string"), 
        '  Input filename undef' ;

    $in = '';    
    eval { $a = $Func->($in, \$x) ;} ;
    like $@, mkErr("^$TopType: input filename is undef or null string"), 
        '  Input filename empty' ;

    $in = 'abc';    
    my $lex1 = new LexFile($in) ;
    writeFile($in, "abc");
    my $out = $in ;
    eval { $a = $Func->($in, $out) ;} ;
    like $@, mkErr("^$TopType: input and output filename are identical"),
        '  Input and Output filename are the same';

    eval { $a = $Func->(\$in, \$in) ;} ;
    like $@, mkErr("^$TopType: input and output buffer are identical"),
        '  Input and Output buffer are the same';
        
    my $out_file = "abcde.out";
    my $lex = new LexFile($out_file) ;
    open OUT, ">$out_file" ;
    eval { $a = $Func->(\*OUT, \*OUT) ;} ;
    like $@, mkErr("^$TopType: input and output handle are identical"),
        '  Input and Output handle are the same';
        
    close OUT;
    is -s $out_file, 0, "  File zero length" ;
    {
        my %x = () ;
        my $object = bless \%x, "someClass" ;

        # Buffer not a scalar reference
        #eval { $a = $Func->(\$x, \%x) ;} ;
        eval { $a = $Func->(\$x, $object) ;} ;
        like $@, mkErr("^$TopType: illegal output parameter"),
            '  Bad Output Param';
            

        #eval { $a = $Func->(\%x, \$x) ;} ;
        eval { $a = $Func->($object, \$x) ;} ;
        like $@, mkErr("^$TopType: illegal input parameter"),
            '  Bad Input Param';
    }

    my $filename = 'abc.def';
    ok ! -e $filename, "  input file '$filename' does not exist";
    $a = $Func->($filename, \$x) ;
    is $a, undef, "  $TopType returned undef";
    like $$Error, "/^input file '$filename' does not exist\$/", "  input File '$filename' does not exist";
        
    $filename = '/tmp/abd/abc.def';
    ok ! -e $filename, "  output File '$filename' does not exist";
    $a = $Func->(\$x, $filename) ;
    is $a, undef, "  $TopType returned undef";
    like $$Error, ("/^(cannot open file '$filename'|input file '$filename' does not exist):/"), "  output File '$filename' does not exist";
        
    $a = $Func->(\$x, '<abc>') ;
    is $a, undef, "  $TopType returned undef";
    like $$Error, "/Need input fileglob for outout fileglob/",
            '  Output fileglob with no input fileglob';

    $a = $Func->('<abc)>', '<abc>') ;
    is $a, undef, "  $TopType returned undef";
    like $$Error, "/Unmatched \\) in input fileglob/",
            "  Unmatched ) in input fileglob";
}

foreach my $bit ('IO::Uncompress::Gunzip',
                 'IO::Uncompress::Inflate',
                 'IO::Uncompress::RawInflate',
                 'IO::Uncompress::AnyInflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $data = "mary had a little lamb" ;
    my $keep = $data ;

    for my $trans ( 0, 1)
    {
        title "Non-compressed data with $TopType, Transparent => $trans ";
        my $a;
        my $x ;
        my $out = '' ;

        $a = $Func->(\$data, \$out, Transparent => $trans) ;

        is $data, $keep, "  Input buffer not changed" ;

        if ($trans)
        {
            ok $a, "  $TopType returned true" ;
            is $out, $data, "  got expected output" ;
            ok ! $$Error, "  no error [$$Error]" ;
        }
        else
        {
            ok ! $a, "  $TopType returned false" ;
            #like $$Error, '/xxx/', "  error" ;
            ok $$Error, "  error is '$$Error'" ;
        }
    }
}

foreach my $bit ('IO::Compress::Gzip',     
                 'IO::Compress::Deflate', 
                 'IO::Compress::RawDeflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);
    my $TopTypeInverse = getInverse($bit);
    my $FuncInverse = getTopFuncRef($TopTypeInverse);
    my $ErrorInverse = getErrorRef($TopTypeInverse);

    title "$TopTypeInverse - corrupt data";

    my $data = "abcd" x 100 ;
    my $out;

    ok $Func->(\$data, \$out), "  $TopType ok";

    # corrupt the compressed data
    substr($out, -10, 10) = "x" x 10 ;

    my $result;
    ok ! $FuncInverse->(\$out => \$result, Transparent => 0), "  $TopTypeInverse ok";
    ok $$ErrorInverse, "  Got error '$$ErrorInverse'" ;

    #is $result, $data, "  data ok";

    ok ! anyinflate(\$out => \$result, Transparent => 0), "  anyinflate ok";
    ok $AnyInflateError, "  Got error '$AnyInflateError'" ;
}


foreach my $bit ('IO::Compress::Gzip',     
                 'IO::Compress::Deflate', 
                 'IO::Compress::RawDeflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);
    my $TopTypeInverse = getInverse($bit);
    my $FuncInverse = getTopFuncRef($TopTypeInverse);

    for my $append ( 1, 0 )
    {
        my $already = '';
        $already = 'abcde' if $append ;

        for my $buffer ( undef, '', "abcde" )
        {

            my $disp_content = defined $buffer ? $buffer : '<undef>' ;

            my $keep = $buffer;
            my $out_file = "abcde.out";
            my $in_file = "abcde.in";

            {
                title "$TopType - From Buff to Buff content '$disp_content' Append $append" ;

                my $output = $already;
                ok &$Func(\$buffer, \$output, Append => $append), '  Compressed ok' ;

                is $keep, $buffer, "  Input buffer not changed" ;
                my $got = anyUncompress(\$output, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Buff to Array Ref content '$disp_content' Append $append" ;

                my @output = ('first') ;
                ok &$Func(\$buffer, \@output, Append => $append), '  Compressed ok' ;

                is $output[0], 'first', "  Array[0] unchanged";
                is $keep, $buffer, "  Input buffer not changed" ;
                my $got = anyUncompress($output[1]);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";
            }

            {
                title "$TopType - From Array Ref to Array Ref content '$disp_content' Append $append" ;

                my @output = ('first') ;
                my @input = ( \$buffer);
                ok &$Func(\@input, \@output, Append => $append), '  Compressed ok' ;

                is $output[0], 'first', "  Array[0] unchanged";
                is $keep, $buffer, "  Input buffer not changed" ;
                my $got = anyUncompress($output[1]);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Buff to Filename content '$disp_content' Append $append" ;

                my $lex = new LexFile($out_file) ;
                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);

                ok &$Func(\$buffer, $out_file, Append => $append), '  Compressed ok' ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";
            }

            {
                title "$TopType - From Buff to Handle content '$disp_content' Append $append" ;

                my $lex = new LexFile($out_file) ;

                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);
                my $of = new IO::File ">>$out_file" ;
                ok $of, "  Created output filehandle" ;

                ok &$Func(\$buffer, $of, AutoClose => 1, Append => $append), '  Compressed ok' ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";
            }


            {
                title "$TopType - From Filename to Filename content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);

                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);

                ok &$Func($in_file => $out_file, Append => $append), '  Compressed ok' ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Filename to Handle content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);

                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);
                my $out = new IO::File ">>$out_file" ;

                ok &$Func($in_file, $out, AutoClose => 1, Append => $append), '  Compressed ok' ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Filename to Buffer content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);

                my $out = $already;

                ok &$Func($in_file => \$out, Append => $append), '  Compressed ok' ;

                my $got = anyUncompress(\$out, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $got, $buffer, "  Uncompressed matches original";

            }
            
            {
                title "$TopType - From Handle to Filename content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);
                my $in = new IO::File "<$in_file" ;

                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);

                ok &$Func($in, $out_file, Append => $append), '  Compressed ok' 
                    or diag "error is $GzipError" ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $buffer, $got, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Handle to Handle content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);
                my $in = new IO::File "<$in_file" ;

                ok ! -e $out_file, "  Output file does not exist";
                writeFile($out_file, $already);
                my $out = new IO::File ">>$out_file" ;

                ok &$Func($in, $out, AutoClose => 1, Append => $append), '  Compressed ok' ;

                ok -e $out_file, "  Created output file";
                my $got = anyUncompress($out_file, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $buffer, $got, "  Uncompressed matches original";

            }

            {
                title "$TopType - From Handle to Buffer content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);
                my $in = new IO::File "<$in_file" ;

                my $out = $already ;

                ok &$Func($in, \$out, Append => $append), '  Compressed ok' ;

                my $got = anyUncompress(\$out, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $buffer, $got, "  Uncompressed matches original";

            }

            {
                title "$TopType - From stdin (via '-') to Buffer content '$disp_content' Append $append" ;

                my $lex = new LexFile($in_file, $out_file) ;
                writeFile($in_file, $buffer);

                   open(SAVEIN, "<&STDIN");
                my $dummy = fileno SAVEIN ;
                ok open(STDIN, "<$in_file"), "  redirect STDIN";

                my $out = $already;

                ok &$Func('-', \$out, Append => $append), '  Compressed ok' 
                    or diag $$Error ;

                   open(STDIN, "<&SAVEIN");

                my $got = anyUncompress(\$out, $already);
                $got = undef if ! defined $buffer && $got eq '' ;
                is $buffer, $got, "  Uncompressed matches original";

            }

        }
    }
}

foreach my $bit ('IO::Compress::Gzip',     
                 'IO::Compress::Deflate', 
                 'IO::Compress::RawDeflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $TopTypeInverse = getInverse($bit);
    my $FuncInverse = getTopFuncRef($TopTypeInverse);

    my ($file1, $file2) = ("file1", "file2");
    my $lex = new LexFile($file1, $file2) ;

    writeFile($file1, "data1");
    writeFile($file2, "data2");
    my $of = new IO::File "<$file1" ;
    ok $of, "  Created output filehandle" ;

    my @input = (   undef, "", $file2, \undef, \'', \"abcde", $of) ;
    my @expected = ("", "", $file2, "", "", "abcde", "data1");
    my @uexpected = ("", "", "data2", "", "", "abcde", "data1");

    my @keep = @input ;

    {
        title "$TopType - From Array Ref to Array Ref" ;

        my @output = ('first') ;
        ok &$Func(\@input, \@output, AutoClose => 0), '  Compressed ok' ;

        is $output[0], 'first', "  Array[0] unchanged";

        is_deeply \@input, \@keep, "  Input array not changed" ;
        my @got = shift @output;
        foreach (@output) { push @got, anyUncompress($_) }

        is_deeply \@got, ['first', @expected], "  Got Expected uncompressed data";

    }

    {
        title "$TopType - From Array Ref to Buffer" ;

        # rewind the filehandle
        $of->open("<$file1") ;

        my $output  ;
        ok &$Func(\@input, \$output, AutoClose => 0), '  Compressed ok' ;

        my $got = anyUncompress(\$output);

        is $got, join('', @expected), "  Got Expected uncompressed data";
    }

    {
        title "$TopType - From Array Ref to Filename" ;

        my ($file3) = ("file3");
        my $lex = new LexFile($file3) ;

        # rewind the filehandle
        $of->open("<$file1") ;

        my $output  ;
        ok &$Func(\@input, $file3, AutoClose => 0), '  Compressed ok' ;

        my $got = anyUncompress($file3);

        is $got, join('', @expected), "  Got Expected uncompressed data";
    }

    {
        title "$TopType - From Array Ref to Filehandle" ;

        my ($file3) = ("file3");
        my $lex = new LexFile($file3) ;

        my $fh3 = new IO::File ">$file3";

        # rewind the filehandle
        $of->open("<$file1") ;

        my $output  ;
        ok &$Func(\@input, $fh3, AutoClose => 0), '  Compressed ok' ;

        $fh3->close();

        my $got = anyUncompress($file3);

        is $got, join('', @expected), "  Got Expected uncompressed data";
    }
}

foreach my $bit ('IO::Compress::Gzip',     
                 'IO::Compress::Deflate', 
                 'IO::Compress::RawDeflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $TopTypeInverse = getInverse($bit);
    my $FuncInverse = getTopFuncRef($TopTypeInverse);

    my @inFiles  = map { "in$_.tmp"  } 1..4;
    my @outFiles = map { "out$_.tmp" } 1..4;
    my $lex = new LexFile(@inFiles, @outFiles);

    writeFile($_, "data $_") foreach @inFiles ;
    
    {
        title "$TopType - Hash Ref: to filename" ;

        my $output ;
        ok &$Func( { $inFiles[0] => $outFiles[0],
                     $inFiles[1] => $outFiles[1],
                     $inFiles[2] => $outFiles[2] } ), '  Compressed ok' ;

        foreach (0 .. 2)
        {
            my $got = anyUncompress($outFiles[$_]);
            is $got, "data $inFiles[$_]", "  Uncompressed $_ matches original";
        }
    }

    {
        title "$TopType - Hash Ref: to buffer" ;

        my @buffer ;
        ok &$Func( { $inFiles[0] => \$buffer[0],
                     $inFiles[1] => \$buffer[1],
                     $inFiles[2] => \$buffer[2] } ), '  Compressed ok' ;

        foreach (0 .. 2)
        {
            my $got = anyUncompress(\$buffer[$_]);
            is $got, "data $inFiles[$_]", "  Uncompressed $_ matches original";
        }
    }

    {
        title "$TopType - Hash Ref: to undef" ;

        my @buffer ;
        my %hash = ( $inFiles[0] => undef,
                     $inFiles[1] => undef,
                     $inFiles[2] => undef, 
                 );  

        ok &$Func( \%hash ), '  Compressed ok' ;

        foreach (keys %hash)
        {
            my $got = anyUncompress(\$hash{$_});
            is $got, "data $_", "  Uncompressed $_ matches original";
        }
    }

    {
        title "$TopType - Filename to Hash Ref" ;

        my %output ;
        ok &$Func( $inFiles[0] => \%output), '  Compressed ok' ;

        is keys %output, 1, "  one pair in hash" ;
        my ($k, $v) = each %output;
        is $k, $inFiles[0], "  key is '$inFiles[0]'";
        my $got = anyUncompress($v);
        is $got, "data $inFiles[0]", "  Uncompressed matches original";
    }

    {
        title "$TopType - File Glob to Hash Ref" ;

        my %output ;
        ok &$Func( '<in*.tmp>' => \%output), '  Compressed ok' ;

        is keys %output, 4, "  four pairs in hash" ;
        foreach my $fil (@inFiles)
        {
            ok exists $output{$fil}, "  key '$fil' exists" ;
            my $got = anyUncompress($output{$fil});
            is $got, "data $fil", "  Uncompressed matches original";
        }
    }


#    if (0)
#    {
#        title "$TopType - Hash Ref to Array Ref" ;
#
#        my @output = ('first') ;
#        ok &$Func( { \@input, \@output } , AutoClose => 0), '  Compressed ok' ;
#
#        is $output[0], 'first', "  Array[0] unchanged";
#
#        is_deeply \@input, \@keep, "  Input array not changed" ;
#        my @got = shift @output;
#        foreach (@output) { push @got, anyUncompress($_) }
#
#        is_deeply \@got, ['first', @expected], "  Got Expected uncompressed data";
#
#    }
#
#    if (0)
#    {
#        title "$TopType - From Array Ref to Buffer" ;
#
#        # rewind the filehandle
#        $of->open("<$file1") ;
#
#        my $output  ;
#        ok &$Func(\@input, \$output, AutoClose => 0), '  Compressed ok' ;
#
#        my $got = anyUncompress(\$output);
#
#        is $got, join('', @expected), "  Got Expected uncompressed data";
#    }
#
#    if (0)
#    {
#        title "$TopType - From Array Ref to Filename" ;
#
#        my ($file3) = ("file3");
#        my $lex = new LexFile($file3) ;
#
#        # rewind the filehandle
#        $of->open("<$file1") ;
#
#        my $output  ;
#        ok &$Func(\@input, $file3, AutoClose => 0), '  Compressed ok' ;
#
#        my $got = anyUncompress($file3);
#
#        is $got, join('', @expected), "  Got Expected uncompressed data";
#    }
#
#    if (0)
#    {
#        title "$TopType - From Array Ref to Filehandle" ;
#
#        my ($file3) = ("file3");
#        my $lex = new LexFile($file3) ;
#
#        my $fh3 = new IO::File ">$file3";
#
#        # rewind the filehandle
#        $of->open("<$file1") ;
#
#        my $output  ;
#        ok &$Func(\@input, $fh3, AutoClose => 0), '  Compressed ok' ;
#
#        $fh3->close();
#
#        my $got = anyUncompress($file3);
#
#        is $got, join('', @expected), "  Got Expected uncompressed data";
#    }
}

foreach my $bit ('IO::Compress::Gzip',     
                 'IO::Compress::Deflate', 
                 'IO::Compress::RawDeflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    for my $files ( [qw(a1)], [qw(a1 a2 a3)] )
    {

        my $tmpDir1 = 'tmpdir1';
        my $tmpDir2 = 'tmpdir2';
        my $lex = new LexDir($tmpDir1, $tmpDir2) ;

        mkdir $tmpDir1, 0777;
        mkdir $tmpDir2, 0777;

        ok   -d $tmpDir1, "  Temp Directory $tmpDir1 exists";
        #ok ! -d $tmpDir2, "  Temp Directory $tmpDir2 does not exist";

        my @files = map { "$tmpDir1/$_.tmp" } @$files ;
        foreach (@files) { writeFile($_, "abc $_") }

        my @expected = map { "abc $_" } @files ;
        my @outFiles = map { s/$tmpDir1/$tmpDir2/; $_ } @files ;

        {
            title "$TopType - From FileGlob to FileGlob files [@$files]" ;

            ok &$Func("<$tmpDir1/a*.tmp>" => "<$tmpDir2/a#1.tmp>"), '  Compressed ok' 
                or diag $$Error ;

            my @copy = @expected;
            for my $file (@outFiles)
            {
                is anyUncompress($file), shift @copy, "  got expected from $file" ;
            }

            is @copy, 0, "  got all files";
        }

        {
            title "$TopType - From FileGlob to Array files [@$files]" ;

            my @buffer = ('first') ;
            ok &$Func("<$tmpDir1/a*.tmp>" => \@buffer), '  Compressed ok' 
                or diag $$Error ;

            is shift @buffer, 'first';

            my @copy = @expected;
            for my $buffer (@buffer)
            {
                is anyUncompress($buffer), shift @copy, "  got expected " ;
            }

            is @copy, 0, "  got all files";
        }

        {
            title "$TopType - From FileGlob to Buffer files [@$files]" ;

            my $buffer ;
            ok &$Func("<$tmpDir1/a*.tmp>" => \$buffer), '  Compressed ok' 
                or diag $$Error ;

            #hexDump(\$buffer);

            my $got = anyUncompress([ \$buffer, MultiStream => 1 ]);

            is $got, join("", @expected), "  got expected" ;
        }

        {
            title "$TopType - From FileGlob to Filename files [@$files]" ;

            my $filename = "abcde";
            my $lex = new LexFile($filename) ;
            
            ok &$Func("<$tmpDir1/a*.tmp>" => $filename), '  Compressed ok' 
                or diag $$Error ;

            #hexDump(\$buffer);

            my $got = anyUncompress([$filename, MultiStream => 1]);

            is $got, join("", @expected), "  got expected" ;
        }

        {
            title "$TopType - From FileGlob to Filehandle files [@$files]" ;

            my $filename = "abcde";
            my $lex = new LexFile($filename) ;
            my $fh = new IO::File ">$filename";
            
            ok &$Func("<$tmpDir1/a*.tmp>" => $fh, AutoClose => 1), '  Compressed ok' 
                or diag $$Error ;

            #hexDump(\$buffer);

            my $got = anyUncompress([$filename, MultiStream => 1]);

            is $got, join("", @expected), "  got expected" ;
        }
    }

}

foreach my $bit ('IO::Uncompress::Gunzip',     
                 'IO::Uncompress::Inflate', 
                 'IO::Uncompress::RawInflate',
                 'IO::Uncompress::AnyInflate',
                )
{
    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $buffer = "abcde" ;
    my $buffer2 = "ABCDE" ;
    my $keep_orig = $buffer;

    my $comp = compressBuffer($TopType, $buffer) ;
    my $comp2 = compressBuffer($TopType, $buffer2) ;
    my $keep_comp = $comp;

    my $incumbent = "incumbent data" ;

    for my $append (0, 1)
    {
        my $expected = $buffer ;
        $expected = $incumbent . $buffer if $append ;

        {
            title "$TopType - From Buff to Buff, Append($append)" ;

            my $output ;
            $output = $incumbent if $append ;
            ok &$Func(\$comp, \$output, Append => $append), '  Uncompressed ok' ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $output, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Buff to Array, Append($append)" ;

            my @output = ('first');
            #$output = $incumbent if $append ;
            ok &$Func(\$comp, \@output, Append => $append), '  Uncompressed ok' ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $output[0], 'first', "  Uncompressed matches original";
            is ${ $output[1] }, $buffer, "  Uncompressed matches original"
                or diag $output[1] ;
            is @output, 2, "  only 2 elements in the array" ;
        }

        {
            title "$TopType - From Buff to Filename, Append($append)" ;

            my $out_file = "abcde";
            my $lex = new LexFile($out_file) ;
            if ($append)
              { writeFile($out_file, $incumbent) }
            else
              { ok ! -e $out_file, "  Output file does not exist" }

            ok &$Func(\$comp, $out_file, Append => $append), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Buff to Handle, Append($append)" ;

            my $out_file = "abcde";
            my $lex = new LexFile($out_file) ;
            my $of ;
            if ($append) {
                writeFile($out_file, $incumbent) ;
                $of = new IO::File "+< $out_file" ;
            }
            else {
                ok ! -e $out_file, "  Output file does not exist" ;
                $of = new IO::File "> $out_file" ;
            }
            isa_ok $of, 'IO::File', '  $of' ;

            ok &$Func(\$comp, $of, Append => $append, AutoClose => 1), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Filename to Filename, Append($append)" ;

            my $out_file = "abcde.out";
            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file, $out_file) ;
            if ($append)
              { writeFile($out_file, $incumbent) }
            else
              { ok ! -e $out_file, "  Output file does not exist" }

            writeFile($in_file, $comp);

            ok &$Func($in_file, $out_file, Append => $append), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Filename to Handle, Append($append)" ;

            my $out_file = "abcde.out";
            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file, $out_file) ;
            my $out ;
            if ($append) {
                writeFile($out_file, $incumbent) ;
                $out = new IO::File "+< $out_file" ;
            }
            else {
                ok ! -e $out_file, "  Output file does not exist" ;
                $out = new IO::File "> $out_file" ;
            }
            isa_ok $out, 'IO::File', '  $out' ;

            writeFile($in_file, $comp);

            ok &$Func($in_file, $out, Append => $append, AutoClose => 1), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Filename to Buffer, Append($append)" ;

            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file) ;
            writeFile($in_file, $comp);

            my $output ;
            $output = $incumbent if $append ;

            ok &$Func($in_file, \$output, Append => $append), '  Uncompressed ok' ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $output, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Handle to Filename, Append($append)" ;

            my $out_file = "abcde.out";
            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file, $out_file) ;
            if ($append)
              { writeFile($out_file, $incumbent) }
            else
              { ok ! -e $out_file, "  Output file does not exist" }

            writeFile($in_file, $comp);
            my $in = new IO::File "<$in_file" ;

            ok &$Func($in, $out_file, Append => $append), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Handle to Handle, Append($append)" ;

            my $out_file = "abcde.out";
            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file, $out_file) ;
            my $out ;
            if ($append) {
                writeFile($out_file, $incumbent) ;
                $out = new IO::File "+< $out_file" ;
            }
            else {
                ok ! -e $out_file, "  Output file does not exist" ;
                $out = new IO::File "> $out_file" ;
            }
            isa_ok $out, 'IO::File', '  $out' ;

            writeFile($in_file, $comp);
            my $in = new IO::File "<$in_file" ;

            ok &$Func($in, $out, Append => $append, AutoClose => 1), '  Uncompressed ok' ;

            ok -e $out_file, "  Created output file";
            my $content = readFile($out_file) ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $content, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From Filename to Buffer, Append($append)" ;

            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file) ;
            writeFile($in_file, $comp);
            my $in = new IO::File "<$in_file" ;

            my $output ;
            $output = $incumbent if $append ;

            ok &$Func($in, \$output, Append => $append), '  Uncompressed ok' ;

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $output, $expected, "  Uncompressed matches original";
        }

        {
            title "$TopType - From stdin (via '-') to Buffer content, Append($append) " ;

            my $in_file = "abcde.in";
            my $lex = new LexFile($in_file) ;
            writeFile($in_file, $comp);

               open(SAVEIN, "<&STDIN");
            my $dummy = fileno SAVEIN ;
            ok open(STDIN, "<$in_file"), "  redirect STDIN";

            my $output ;
            $output = $incumbent if $append ;

            ok &$Func('-', \$output, Append => $append), '  Uncompressed ok' 
                or diag $$Error ;

               open(STDIN, "<&SAVEIN");

            is $keep_comp, $comp, "  Input buffer not changed" ;
            is $output, $expected, "  Uncompressed matches original";
        }
    }

    {
        title "$TopType - From Handle to Buffer, InputLength" ;

        my $out_file = "abcde.out";
        my $in_file = "abcde.in";
        my $lex = new LexFile($in_file, $out_file) ;
        my $out ;

        my $expected = $buffer ;
        my $appended = 'appended';
        my $len_appended = length $appended;
        writeFile($in_file, $comp . $appended . $comp . $appended) ;
        my $in = new IO::File "<$in_file" ;

        ok &$Func($in, \$out, Transparent => 0, InputLength => length $comp), '  Uncompressed ok' ;

        is $out, $expected, "  Uncompressed matches original";

        my $buff;
        is $in->read($buff, $len_appended), $len_appended, "  Length of Appended data ok";
        is $buff, $appended, "  Appended data ok";

        $out = '';
        ok &$Func($in, \$out, Transparent => 0, InputLength => length $comp), '  Uncompressed ok' ;

        is $out, $expected, "  Uncompressed matches original";

        $buff = '';
        is $in->read($buff, $len_appended), $len_appended, "  Length of Appended data ok";
        is $buff, $appended, "  Appended data ok";
    }

    for my $stdin ('-', *STDIN) # , \*STDIN)
    {
        title "$TopType - From stdin (via $stdin) to Buffer content, InputLength" ;

        my $lex = new LexFile my $in_file ;
        my $expected = $buffer ;
        my $appended = 'appended';
        my $len_appended = length $appended;
        writeFile($in_file, $comp . $appended ) ;

           open(SAVEIN, "<&STDIN");
        my $dummy = fileno SAVEIN ;
        ok open(STDIN, "<$in_file"), "  redirect STDIN";

        my $output ;

        ok &$Func($stdin, \$output, Transparent => 0, InputLength => length $comp), '  Uncompressed ok' 
            or diag $$Error ;

        my $buff ;
        is read(STDIN, $buff, $len_appended), $len_appended, "  Length of Appended data ok";

        is $output, $expected, "  Uncompressed matches original";
        is $buff, $appended, "  Appended data ok";

          open(STDIN, "<&SAVEIN");
    }
}

foreach my $bit ('IO::Uncompress::Gunzip',     
                 'IO::Uncompress::Inflate', 
                 'IO::Uncompress::RawInflate',
                 'IO::Uncompress::AnyInflate',
                )
{
    # TODO -- Add Append mode tests

    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $buffer = "abcde" ;
    my $keep_orig = $buffer;


    my $null = compressBuffer($TopType, "") ;
    my $undef = compressBuffer($TopType, undef) ;
    my $comp = compressBuffer($TopType, $buffer) ;
    my $keep_comp = $comp;

    my $incumbent = "incumbent data" ;

    my ($file1, $file2) = ("file1", "file2");
    my $lex = new LexFile($file1, $file2) ;

    writeFile($file1, compressBuffer($TopType,"data1"));
    writeFile($file2, compressBuffer($TopType,"data2"));

    my $of = new IO::File "<$file1" ;
    ok $of, "  Created output filehandle" ;

    my @input    = ($file2, \$undef, \$null, \$comp, $of) ;
    my @expected = ('data2', '',      '',    'abcde', 'data1');

    my @keep = @input ;

    {
        title "$TopType - From ArrayRef to Buffer" ;

        my $output  ;
        ok &$Func(\@input, \$output, AutoClose => 0), '  UnCompressed ok' ;

        is $output, join('', @expected)
    }

    {
        title "$TopType - From ArrayRef to Filename" ;

        my $output  = 'abc';
        my $lex = new LexFile $output;
        $of->open("<$file1") ;

        ok &$Func(\@input, $output, AutoClose => 0), '  UnCompressed ok' ;

        is readFile($output), join('', @expected)
    }

    {
        title "$TopType - From ArrayRef to Filehandle" ;

        my $output  = 'abc';
        my $lex = new LexFile $output;
        my $fh = new IO::File ">$output" ;
        $of->open("<$file1") ;

        ok &$Func(\@input, $fh, AutoClose => 0), '  UnCompressed ok' ;
        $fh->close;

        is readFile($output), join('', @expected)
    }

    {
        title "$TopType - From Array Ref to Array Ref" ;

        my @output = (\'first') ;
        $of->open("<$file1") ;
        ok &$Func(\@input, \@output, AutoClose => 0), '  UnCompressed ok' ;

        is_deeply \@input, \@keep, "  Input array not changed" ;
        is_deeply [map { defined $$_ ? $$_ : "" } @output], 
                  ['first', @expected], 
                  "  Got Expected uncompressed data";

    }
}

foreach my $bit ('IO::Uncompress::Gunzip',     
                 'IO::Uncompress::Inflate', 
                 'IO::Uncompress::RawInflate',
                 'IO::Uncompress::AnyInflate',
                )
{
    # TODO -- Add Append mode tests

    my $Error = getErrorRef($bit);
    my $Func = getTopFuncRef($bit);
    my $TopType = getTopFuncName($bit);

    my $tmpDir1 = 'tmpdir1';
    my $tmpDir2 = 'tmpdir2';
    my $lex = new LexDir($tmpDir1, $tmpDir2) ;

    mkdir $tmpDir1, 0777;
    mkdir $tmpDir2, 0777;

    ok   -d $tmpDir1, "  Temp Directory $tmpDir1 exists";
    #ok ! -d $tmpDir2, "  Temp Directory $tmpDir2 does not exist";

    my @files = map { "$tmpDir1/$_.tmp" } qw( a1 a2 a3) ;
    foreach (@files) { writeFile($_, compressBuffer($TopType, "abc $_")) }

    my @expected = map { "abc $_" } @files ;
    my @outFiles = map { s/$tmpDir1/$tmpDir2/; $_ } @files ;

    {
        title "$TopType - From FileGlob to FileGlob" ;

        ok &$Func("<$tmpDir1/a*.tmp>" => "<$tmpDir2/a#1.tmp>"), '  UnCompressed ok' 
            or diag $$Error ;

        my @copy = @expected;
        for my $file (@outFiles)
        {
            is readFile($file), shift @copy, "  got expected from $file" ;
        }

        is @copy, 0, "  got all files";
    }

    {
        title "$TopType - From FileGlob to Arrayref" ;

        my @output = (\'first');
        ok &$Func("<$tmpDir1/a*.tmp>" => \@output), '  UnCompressed ok' 
            or diag $$Error ;

        my @copy = ('first', @expected);
        for my $data (@output)
        {
            is $$data, shift @copy, "  got expected data" ;
        }

        is @copy, 0, "  got all files";
    }

    {
        title "$TopType - From FileGlob to Buffer" ;

        my $output ;
        ok &$Func("<$tmpDir1/a*.tmp>" => \$output), '  UnCompressed ok' 
            or diag $$Error ;

        is $output, join('', @expected), "  got expected uncompressed data";
    }

    {
        title "$TopType - From FileGlob to Filename" ;

        my $output = 'abc' ;
        my $lex = new LexFile $output ;
        ok ! -e $output, "  $output does not exist" ;
        ok &$Func("<$tmpDir1/a*.tmp>" => $output), '  UnCompressed ok' 
            or diag $$Error ;

        ok -e $output, "  $output does exist" ;
        is readFile($output), join('', @expected), "  got expected uncompressed data";
    }

    {
        title "$TopType - From FileGlob to Filehandle" ;

        my $output = 'abc' ;
        my $lex = new LexFile $output ;
        my $fh = new IO::File ">$output" ;
        ok &$Func("<$tmpDir1/a*.tmp>" => $fh, AutoClose => 1), '  UnCompressed ok' 
            or diag $$Error ;

        ok -e $output, "  $output does exist" ;
        is readFile($output), join('', @expected), "  got expected uncompressed data";
    }

}

foreach my $TopType ('IO::Compress::Gzip::gzip', 
                     'IO::Compress::Deflate', 
                     'IO::Compress::RawDeflate', 
                     # TODO -- add the inflate classes
                    )
{
    my $Error = getErrorRef($TopType);
    my $Func = getTopFuncRef($TopType);
    my $Name = getTopFuncName($TopType);

    title "More write tests" ;

    my $file1 = "file1" ;
    my $file2 = "file2" ;
    my $file3 = "file3" ;
    my $lex = new LexFile $file1, $file2, $file3 ;

    writeFile($file1, "F1");
    writeFile($file2, "F2");
    writeFile($file3, "F3");

    my @data = (
          [ '[]',                                    ""     ],
          [ '[\""]',                                 ""     ],
          [ '[\undef]',                              ""     ],
          [ '[\"abcd"]',                             "abcd" ],
          [ '[\"ab", \"cd"]',                        "abcd" ],

          [ '$fh2',                                  "F2"   ],
          [ '[\"a", $fh1, \"bc"]',                   "aF1bc"],
        ) ;


    foreach my $data (@data)
    {
        my ($send, $get) = @$data ;

        my $fh1 = new IO::File "< $file1" ;
        my $fh2 = new IO::File "< $file2" ;
        my $fh3 = new IO::File "< $file3" ;

        title "$send";
        my $copy;
        eval "\$copy = $send";
        my $Answer ;
        ok &$Func($copy, \$Answer), "  $Name ok";

        my $got = anyUncompress(\$Answer);
        is $got, $get, "  got expected output" ;
        ok ! $$Error,  "  no error"
            or diag "Error is $$Error";

    }

    title "Array Input Error tests" ;

    @data = (
               '[[]]', 
               '[[[]]]',
               '[[\"ab"], [\"cd"]]',
            ) ;


    foreach my $send (@data)
    {
        my $fh1 = new IO::File "< $file1" ;
        my $fh2 = new IO::File "< $file2" ;
        my $fh3 = new IO::File "< $file3" ;

        title "$send";
        my $copy;
        eval "\$copy = $send";
        my $Answer ;
        ok ! &$Func($copy, \$Answer), "  $Name fails";

        is $$Error, "unknown input parameter", "  got error message";

    }
}

sub gzipGetHeader
{
    my $in = shift;
    my $content = shift ;
    my %opts = @_ ;

    my $out ;
    my $got ;

    ok IO::Compress::Gzip::gzip($in, \$out, %opts), "  gzip ok" ;
    ok IO::Uncompress::Gunzip::gunzip(\$out, \$got), "  gunzip ok" 
        or diag $GunzipError ;
    is $got, $content, "  got expected content" ;

    my $gunz = new IO::Uncompress::Gunzip \$out, Strict => 0
        or diag "GunzipError is $IO::Uncompress::Gunzip::GunzipError" ;
    ok $gunz, "  Created IO::Uncompress::Gunzip object";
    my $hdr = $gunz->getHeaderInfo();
    ok $hdr, "  got Header info";
    my $uncomp ;
    ok $gunz->read($uncomp), " read ok" ;
    is $uncomp, $content, "  got expected content";
    ok $gunz->close, "  closed ok" ;

    return $hdr ;
    
}

{
    title "Check gzip header default NAME & MTIME settings" ;

    my $file1 = "file1" ;
    my $lex = new LexFile $file1;

    my $content = "hello ";
    my $hdr ;
    my $mtime ;

    writeFile($file1, $content);
    $mtime = (stat($file1))[8];
    # make sure that the gzip file isn't created in the same
    # second as the input file
    sleep 3 ; 
    $hdr = gzipGetHeader($file1, $content);

    is $hdr->{Name}, $file1, "  Name is '$file1'";
    is $hdr->{Time}, $mtime, "  Time is ok";

    title "Override Name" ;

    writeFile($file1, $content);
    $mtime = (stat($file1))[8];
    sleep 3 ; 
    $hdr = gzipGetHeader($file1, $content, Name => "abcde");

    is $hdr->{Name}, "abcde", "  Name is 'abcde'" ;
    is $hdr->{Time}, $mtime, "  Time is ok";

    title "Override Time" ;

    writeFile($file1, $content);
    $hdr = gzipGetHeader($file1, $content, Time => 1234);

    is $hdr->{Name}, $file1, "  Name is '$file1'" ;
    is $hdr->{Time}, 1234,  "  Time is 1234";

    title "Override Name and Time" ;

    writeFile($file1, $content);
    $hdr = gzipGetHeader($file1, $content, Time => 4321, Name => "abcde");

    is $hdr->{Name}, "abcde", "  Name is 'abcde'" ;
    is $hdr->{Time}, 4321, "  Time is 4321";

    title "Filehandle doesn't have default Name or Time" ;
    my $fh = new IO::File "< $file1"
        or diag "Cannot open '$file1': $!\n" ;
    sleep 3 ; 
    my $before = time ;
    $hdr = gzipGetHeader($fh, $content);
    my $after = time ;

    ok ! defined $hdr->{Name}, "  Name is undef";
    cmp_ok $hdr->{Time}, '>=', $before, "  Time is ok";
    cmp_ok $hdr->{Time}, '<=', $after, "  Time is ok";

    $fh->close;

    title "Buffer doesn't have default Name or Time" ;
    my $buffer = $content;
    $before = time ;
    $hdr = gzipGetHeader(\$buffer, $content);
    $after = time ;

    ok ! defined $hdr->{Name}, "  Name is undef";
    cmp_ok $hdr->{Time}, '>=', $before, "  Time is ok";
    cmp_ok $hdr->{Time}, '<=', $after, "  Time is ok";
}

# TODO add more error cases

