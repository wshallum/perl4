#!/usr/bin/perl -w

#
# sisify.pl - package Perl scripts or Perl libraries into SIS files
#
# Copyright (c) 2004-2005 Nokia. All rights reserved.
# The sisify.pl utility is licensed under the same terms as Perl itself.
#

require 5.008;

use strict;

use vars qw($VERSION);

$VERSION = '0.2';

use Getopt::Long;
use File::Temp qw/tempdir/;
use File::Find;
use File::Basename qw/basename dirname/;
use Cwd qw/getcwd/;

BEGIN {
  # This utility has been developed in Windows under cmd.exe with
  # the Series 60 2.6 SDK installed, but for the makesis utility
  # in UNIX/Linux, try e.g. one of the following:
  # http://gnupoc.sourceforge.net/
  # http://symbianos.org/~andreh/ You
  # will also need the 'uidcrc' utility.
  die "$0: Looks like Cygwin, aborting.\n" if exists $ENV{'!C:'};
}

sub die_with_usage {
  if (@_) {
    warn "$0: $_\n" for @_;
  }
  die <<__USAGE__;
$0: Usage:
$0 [--variant=S60|S80] [ --uid=hhhhhhhh ] [ --version=a.b.c ] [ --library=x.y.z ] [ some.pl | Some.pm | somefile | dir ... ]
The uid is the Symbian app uid for the SIS.
The version is the version of the SIS.
The library is the version of Perl under which to install.  If using this,
only specify directories for packaging.
__USAGE__
}

my $SisUid;
my $SisVersion;
my $Library;
my @SisPl;
my @SisPm;
my @SisDir;
my @SisOther;
my $AppName;
my $Debug;
my $ShowPkg;
my $Variant;

my $SisUidDefault     = 0x0acebabe;
my $SisVersionDefault = '0.0.0';
my $VariantDefault    = 'S60';

my %Variant = qw(S60 1 S80 1);

die_with_usage()
  unless GetOptions(
		    'variant=s'		=> \$Variant,
		    'uid=s'		=> \$SisUid,
		    'version=s'		=> \$SisVersion,
		    'debug'		=> \$Debug,
		    'showpkg'		=> \$ShowPkg,
		    'library=s'		=> \$Library,
		    'appname=s'		=> \$AppName,
		   );
die_with_usage("Need to specify what to sisify")
  unless @ARGV;

unless (defined $Variant) {
  warn "$0: Defaulting to $VariantDefault\n";
  $Variant = $VariantDefault;
}

unless (exists $Variant{$Variant}) {
  die "$0: Unknown variant '$Variant'\n";
}

for my $i (@ARGV) {
  if ($i =~ /\.pl$/i) {
    push @SisPl, $i;
  } elsif ($i =~ /\.pm$/i) {
    push @SisPm, $i;
  } elsif (-f $i) {
    push @SisOther, $i;
  } elsif (-d $i) {
    push @SisDir, $i;
  } else {
    die_with_usage("Unknown sisifiable '$i'");
  }
}

sub do_system {
    my $cwd = getcwd();
    print qq{\# system("@_") [cwd "$cwd"]\n};
    return system("@_") == 0;
}

die_with_usage("Must specify something to sisify")
  unless @SisPl || @SisPm || @SisOther || @SisDir;

die_with_usage("With the lib option set, specify only directories")
  if defined $Library && ((@SisPl || @SisPm || @SisOther) || @SisDir == 0);

die_with_usage("Lib must define the Perl 5 version as 5.x.y")
  if defined $Library && $Library !~ /^5.\d+\.\d+$/;

die_with_usage("With the lib option unset, specify at least one .pl file")
  if (! defined $Library && @SisPl == 0);

if (!defined $AppName) {
  if (defined $Library) {
    $AppName = $SisDir[0];
    $AppName =~ tr!/!-!;
  } elsif (@SisPl > 0 && $SisPl[0] =~ /^(.+)\.pl$/i) {
    $AppName = basename($1);
  }
}

die_with_usage("Must either specify appname or at least one .pl file or the lib option")
  unless defined $AppName || defined $Library;

print "[app name '$AppName']\n" if $Debug;

unless (defined $SisUid) {
  $SisUid = $SisUidDefault;
  printf "[default app uid '0x%08x']\n", $SisUid;
} elsif ($SisUid =~ /^(?:0x)?([0-9a-f]{8})$/i) {
  $SisUid = hex($1);
} else {
  die_with_usage("Bad uid '$SisUid'");
}
$SisUid = sprintf "0x%08x", $SisUid;

die_with_usage("Bad uid '$SisUid'")
  if $SisUid !~ /^0x[0-9a-f]{8}$/i;

unless (defined $SisVersion) {
  $SisVersion = $SisVersionDefault;
  print "[default app version '$SisVersionDefault']\n";
} elsif ($SisVersion !~ /^\d+\.\d+\.\d+$/) {
  die_with_usage("Bad version '$SisVersion'")
}

my $tempdir = tempdir( CLEANUP => 1 );

print "[temp directory '$tempdir']\n" if $Debug;

for my $file (@SisPl, @SisPm, @SisOther) {
  print "[copying file '$file']\n" if $Debug;
  die_with_usage("$0: File '$file': $!") unless -f $file;
  my $dir = dirname($file);
  do_system("mkdir $tempdir\\$dir") unless $dir eq '.';
  do_system("copy $file $tempdir");
}
if (@SisPl) {
    do_system("copy $SisPl[0] $tempdir\\default.pl")
	unless $SisPl[0] eq "default.pl";
}
for my $dir (@SisDir) {
  print "[copying directory '$dir']\n" if $Debug;
  do_system("copy $dir $tempdir");
}

my $SisVersionCommas = $SisVersion;

$SisVersionCommas =~ s/\./\,/g;

my @pkg;

push @pkg, qq[&EN;];
push @pkg, qq[#{"$AppName"},($SisUid),$SisVersionCommas];
push @pkg, qq[(0x101F6F88), 0, 0, 0, {"Series60ProductID"}];

my $OWD = getcwd();

$OWD =~ s!/!\\!g;

chdir($tempdir) or die "$0: chdir('$tempdir')\n";

if (@SisPl) {
  if (open(my $fi, "default.pl")) {
    my $fn = "default.pl.new";
    if (open(my $fo, ">$fn")) {
      while (<$fi>) {
	last unless /^\#/;
	print $fo $_;
      }
      print $fo "use lib qw(\\system\\apps\\$AppName \\system\\apps\\$AppName\\lib);\n";
      printf $fo qq[# %d "$SisPl[0]"\n], $.;
      print $fo $_;
      while (<$fi>) {
	print $fo $_;
      }
      close($fo);
    } else {
      die "$0: open '>$fn': $!\n";
    }
    close($fi);
    rename($fn, "default.pl") or die "$0: rename $fn default.pl: $!\n";
    # system("cat -nvet default.pl");
  } else {
    die "$0: open 'default.pl': $!\n";
  }
}


my @c;
find(
     sub {
       if (-f $_) {
	 $File::Find::name =~ s!^\./!!;
	 push @c, $File::Find::name;
       }
     }
     ,
     ".");

for my $i (sort @c) {
  my $j = $i;
  $j =~ s!/!\\!g;
  push @pkg, defined $Library ? qq["$j"-"!:\\System\\Libs\\Perl\\siteperl\\$Library\\$j"] : qq["$j"-"!:\\system\\apps\\$AppName\\$j"];
}

sub hex2data {
  pack("H*", shift); # symbian\hexdump.pl to create the hexdumps.
}

my $APPHEX;
my $RSCHEX;

unless ($Library) {
  # If we package an application we will need both a launching native
  # Symbian application and a resource file for it.  The resource file
  # we can get easily from a stub but for the native app we need to
  # patch in the right Symbian app uids and executable checksums.

  &init_hex; # Initialized $APPHEX and $RSCHEX.

  die "$0: No app template found\n" unless defined $APPHEX && defined $RSCHEX;

  my $app = hex2data($APPHEX);
  my $uidcrc;
  my $uids = "0x10000079 0x100039CE $SisUid";

  my $cmd = "uidcrc $uids |";

  if (open(my $fh, $cmd)) {
    my $line = <$fh>;
    close($fh);
    # 0x10000079 0x100039ce 0x0acebabe 0xc82b1900
    $line =~ s/\r?\n$//;
    if ($line =~ /^$uids (0x[0-9a-f]{8})$/i) {
      $uidcrc = hex($1);
    } else {
      die "$0: uidcrc returned '$line'\n";
    }
  } else {
    die qq[$0: open '$cmd' failed: $!\n];
  }

  my $uid    = hex($SisUid);

  my $oldchk = unpack('V', substr($app, 24, 4));
  my $newchk = ($uid + $oldchk) & 0xFFFFFFFF;

  # printf "# uid    = 0x%08x\n", $uid;
  # printf "# uidcrc = 0x%08x\n", $uidcrc;
  # printf "# oldchk = 0x%08x\n", $oldchk;
  # printf "# newchk = 0x%08x\n", $newchk;

  substr($app,  8, 4) = pack('V', $uid);
  substr($app, 12, 4) = pack('V', $uidcrc);
  substr($app, 24, 4) = pack('V', $newchk);
  
  my $UID_OFFSET = 0x0C7C; # This is where the uid is in the $app.
  substr($app, $UID_OFFSET, 4) = substr($app, 8, 4); # Copy the uid also here.

  if (open(my $fh, ">$AppName.app")) {
    binmode($fh);
    print $fh $app;
    close($fh);
  } else {
    die qq[$0: open '>$AppName.app' failed: $!\n];
  }

  push @pkg, qq["$AppName.app"-"!:\\system\\apps\\$AppName\\$AppName.app"];

  if (open(my $fh, ">$AppName.rsc")) {
    binmode($fh);
    print $fh hex2data($RSCHEX);
    close($fh);
  } else {
    die qq[$0: open '>$AppName.rsc' failed: $!\n];
  }
  push @pkg, qq["$AppName.rsc"-"!:\\system\\apps\\$AppName\\$AppName.rsc"];
}

if ($ShowPkg) {
  for my $l (@pkg) {
    print $l, "\r\n";
  }
} else {
  my $fn = "$AppName.pkg";
  if (open(my $fh, ">$fn")) {
    for my $l (@pkg) {
      print $fh "$l\r\n"; # Note CRLF!
    }
    close($fh);
  } else {
    die qq[$0: Failed to open "$fn" for writing: $!\n];
  }
  my $sis = "$AppName.SIS";
  unlink($sis);
  do_system("dir");
  do_system("makesis $fn");
  unless (-f $sis) {
    die qq[$0: failed to create "$sis"\n];
  }
  do_system("copy $AppName.sis $OWD");
  chdir($OWD);
  system("dir $sis");
  print "\n=== Now transfer $sis to your device ===\n";
}

exit(0);

# To create the hex: print unpack("H*", $data);

sub init_hex {
  # This is Symbian application executable skeleton.
  # You can create the ...\epoc32\release\thumb\urel\foo.app
  # by compiling the PerlApp.cpp with PerlMinSample defined in PerlApp.h.
  # The following executable has been compiled using the Series 60 SDK 2.6
  # for Visual C.
  # Use symbian\hexdump.pl to create the perlappmin.hex for this hexdump.
  if ($Variant eq 'S60') {
      $APPHEX = <<__APP__;
79000010ce390010f61520108581107645504f430020000056176fa5000000000100bf00803e2bde56e1e0000300000180110000000000000010000000001000002000000000000001000000000000100000000007000000f8110000010000003c0f00007c00000000000000fc110000fc140000000000005e01000000b500f0f7f902bc084700000148006870470000280c001000b5011c024800f0b3fc01bc00470000480c001030b585b00490002100f004fd6846049900f046fb684600f01bf9011c049cb4256d006019016004980022002300f002fab6256d0065190020286000f003fa012100f006fa05b030bc01bc0047f0b5071c0e1c1e4878611e48b8611e48f8611e48b8641e48f8641e483860b42464003d192968002910d0786800f018fb2968002905d008688268081c032100f0a3f9b4246400391900200860b62464003d192868002803d000f060fc00202860b96a002905d008688268081c032100f08bf9381c311c00f0adfcf0bc01bc0047c40e0010280f0010180f0010f80e0010040f00105c0c001084b010b595b01790189119921a9301200021002200f07efc041c14a901a800f037fc002808d10090201c17a90222002300f076fc00f032fc00f036fc15b010bc08bc04b018470000f0b5474680b4324ca544071c8846022952d100f0bbfa011c0a687ea8126a00f043f98026f6006e44301c00f07dfa2949301c7eaa002300f07dfac425ed006d44281c00f07ffa244c6c440021224868440160201c042100f07bfa301c00f07efa011c201c2a1c00f07ffa002824d1301c00f074fa011c8420000168448022520000f0f4fb8521090169446846fc22520000f0f2fb84200001684400680f49694409680f4a6a4412680e4b6b441b68fff783ff381c00f070fa00204446002c00d10120094b9d4408bc9846f0bc02bc0847b4f5ffff2c0c0010480a000044080000480800004c0800004c0a000000b50120fff7e6fe01bc004700b5021c80204000814202d00348814206d1101c00f044fa05e00000c10b0000081cfff7e7ff01bc0047000010b500f007f8041c00f0aafb201c10bc02bc084730b5051c302000f0a7fb041c002c05d000f0f2f80748606007482060201c00f0a1fb201c291c00f009f8201c30bc02bc08470000d40c0010e40c001030b5041c0d1c00f0dff8201c291c00f0e1f82068016a201c00f08af830bc01bc0047000000b5044a4260044a026000f0d7f801bc00470000d40c0010e40c001030b584b0041c00f0d1f8051c6846211c00f0d2f82868b8300268281c694600f069f804b030bc01bc0047000030b5051c242000f053fb041c002c04d0291c00f085fb03482060201c30bc02bc08470000940d001070b5b820400000f03ffb061c002e18d000f0c4f90d48b0640d48f0640d4d75610d4cb4610d4bf3610d4ab2640d49f1640d4830600d483060301c6030802100f02ffb301c70bc02bc084700002c0e0010380e0010c40e0010280f0010180f0010f80e0010040f00104c0e00105c0c001010b58b20800000f019fb041c002c03d000f092f902482060201c10bc02bc0847f00d0010002070470047704708477047104770471847704720477047284770473047704738477047404770474847704750477047584770476047704770477047014b1b681847c0463c0f0010014b1b681847c046440f0010014b1b681847c046480f0010014b1b681847c046400f001040b4024e3668b44640bc6047900f0010014b1b681847c04610100010014b1b681847c0462c100010014b1b681847c0461c100010014b1b681847c046a00f0010014b1b681847c04608100010014b1b681847c04618100010014b1b681847c04614100010014b1b681847c046e80f0010014b1b681847c046dc0f0010014b1b681847c046d40f0010014b1b681847c04600100010014b1b681847c046fc0f0010014b1b681847c046980f0010014b1b681847c0468c0f0010014b1b681847c046e40f0010014b1b681847c04628100010014b1b681847c046f40f0010014b1b681847c04604100010014b1b681847c046c40f0010014b1b681847c046d80f0010014b1b681847c046bc0f0010014b1b681847c046a80f0010014b1b681847c046ac0f0010014b1b681847c046cc0f0010014b1b681847c046b80f0010014b1b681847c046b40f0010014b1b681847c046a40f0010014b1b681847c0460c100010014b1b681847c046e00f0010014b1b681847c0469c0f0010014b1b681847c046940f0010014b1b681847c046ec0f0010014b1b681847c046f00f0010014b1b681847c046d00f0010014b1b681847c046b00f0010014b1b681847c046c00f0010014b1b681847c046f80f0010014b1b681847c046c80f0010014b1b681847c04630100010014b1b681847c04634100010014b1b681847c04620100010014b1b681847c04624100010014b1b681847c0463c100010014b1b681847c04638100010014b1b681847c0465410001040b4024e3668b44640bc60474c100010014b1b681847c04650100010014b1b681847c04640100010014b1b681847c04648100010014b1b681847c04644100010014b1b681847c04668100010014b1b681847c046d8100010014b1b681847c04658100010014b1b681847c0468c100010014b1b681847c04624110010014b1b681847c04620110010014b1b681847c04638110010014b1b681847c046e8100010014b1b681847c04698100010014b1b681847c046a8100010014b1b681847c04608110010014b1b681847c046d4100010014b1b681847c046c8100010014b1b681847c04678100010014b1b681847c046ac100010014b1b681847c04614110010014b1b681847c046ec100010014b1b681847c046f0100010014b1b681847c04674100010014b1b681847c046c4100010014b1b681847c04660100010014b1b681847c046e0100010014b1b681847c04694100010014b1b681847c0465c100010014b1b681847c046f4100010014b1b681847c046bc100010014b1b681847c0467c100010014b1b681847c04688100010014b1b681847c046cc100010014b1b681847c04600110010014b1b681847c0460c110010014b1b681847c046f8100010014b1b681847c04690100010014b1b681847c046b8100010014b1b681847c046b4100010014b1b681847c046dc100010014b1b681847c046e4100010014b1b681847c04610110010014b1b681847c0462c11001040b4024e3668b44640bc6047b0100010014b1b681847c04604110010014b1b681847c04670100010014b1b681847c0469c100010014b1b681847c0466410001040b4024e3668b44640bc6047fc100010014b1b681847c04684100010014b1b681847c04680100010014b1b681847c046c0100010014b1b681847c04628110010014b1b681847c0466c10001040b4024e3668b44640bc6047d0100010014b1b681847c046a0100010014b1b681847c04630110010014b1b681847c0463411001040b4024e3668b44640bc6047a4100010014b1b681847c0461c110010014b1b681847c04618110010014b1b681847c04644110010014b1b681847c04664110010014b1b681847c04654110010014b1b681847c04658110010014b1b681847c04648110010014b1b681847c0465c110010014b1b681847c0463c110010014b1b681847c0464c110010014b1b681847c04640110010014b1b681847c04650110010014b1b681847c04660110010014b1b681847c04668110010014b1b681847c0466c110010014b1b681847c0467011001040b4024e3668b44640bc604774110010014b1b681847c0464c0f0010014b1b681847c046840f0010014b1b681847c046880f0010014b1b681847c046640f0010014b1b681847c046740f0010014b1b681847c046540f0010014b1b681847c0465c0f001040b4024e3668b44640bc6047500f0010014b1b681847c046800f0010014b1b681847c0467c0f0010014b1b681847c046700f0010014b1b681847c0466c0f001040b4024e3668b44640bc6047680f0010014b1b681847c046580f0010014b1b681847c046600f0010014b1b681847c046780f00107047000000b5fff72fff01bc0047000000b5fff72fff01bc0047000000b5fff723ff01bc0047000010b581b0039c14380094fff7b1fe01b010bc01bc0047000000b51438fff7d6ff01bc004700b51438fff7aafe01bc004700b51838fff7fcfe02bc084700b51c38fff7f0fe02bc084700b51c38fff7e4fe02bc084700b50438fff774fd02bc084700b50438fff768fd02bc084700b54838fff7a0ff01bc004700b54c38fff7a0ff01bc0047ffffffff00000000ffffffff00000000280c0010480c0010c40e0010280f0010180f0010f80e0010040f00105c0c00102c0c0010d40c0010e40c0010d40c0010e40c0010940d00102c0e0010380e0010c40e0010280f0010180f0010f80e0010040f00104c0e00105c0c0010580d0010f00d0010f61520100a000000640065006600610075006c0074002e0070006c0000000000070000005000650072006c004d0069006e000000000000000000000079000010650a0010710a00101507001021070010fd050010090600107d0a001015060010890a00102d070010210600102d0600102d00001039070010590100104507001051020010510700105d07001069070010950a001075070010810700108d07001099070010a50a0010b10a0010fcffffff00000000910b0010850b00100000000000000000f1020010d1040010dd040010e9040010f5040010010500100d0500101905001025050010310500103d0500104905001055050010610500106d0500107905001085050010910500109d050010a9050010b5050010c1050010cd050010d90500100d030010e5050010f105001000000000000000000d0b0010bd0a0010a5070010190a0010c90a0010b107001031040010bd070010c9070010d5070010e1070010ed070010190a00100000000000000000190b0010f9070010050800103d040010110800101d080010290800103508001041080010090b00104d08001059080010490400105504001065080010710800107d08001061030010d50a001089080010950800100000000000000000250b0010bd0a0010a50700100d000010c90a0010b107001031040010bd070010c9070010d5070010e1070010ed070010390300100000000000000000190a00100000000000000000190a0010390600104506001000000000000000004d0a0010650a0010710a00101507001021070010fd050010090600107d0a001015060010890a00102d070010210600102d06001021090010390700102d090010450700103d090010510700105d07001069070010950a001075070010810700108d07001099070010a50a0010b10a0010ecffffff00000000490b0010bd080010c9080010d5080010e1080010f1080010fd080010310b001009090010550b001015090010b8ffffff000000009d0b0010b4ffffff00000000a90b00103906001045060010e4ffffff00000000790b00106d0b0010e8ffffff00000000610b0010510600105d06001003000000060000001b000000470000003f000000ee020000f502000022030000230300002503000028030000b5040000b6040000d2040000e6040000f304000044050000480500000008000005080000030000000c0000001c0000001d000000210000002800000042000000480000004a000000520000005400000055000000570000005a0000005f0000006000000064000000650000008a0000008b0000008f0000009300000099000000a0000000ad000000b1000000b9000000bb000000c5000000c8000000d0000000d6000000dd000000df000000e2000000e8000000ec000000ff0000000001000014010000150100002401000025010000380100003a010000120000002700000033000000b7000000e3000000e600000011000000140000001e0000001f0000002000000028000000300000003100000033000000340000004000000041000000420000004300000044000000470000004a0000004b0000004c00000050000000510000005200000054000000560000006400000074000000790000007a0000007c0000008200000085000000860000008c0000008e0000008f00000092000000930000009500000096000000970000009b0000009d000000a1000000b3000000c6000000c8000000cc000000ce000000d5000000d6000000de000000e0000000e2000000fd000000080100002201000028010000020000000300000029030000380300003c0300005a0300007c0400008c0400000205000003050000e00500002e0600004b060000040000008905000000000000d103000000030000780200000400000003000000060000001b000000470000008d020000100000003f000000ee020000f502000022030000230300002503000028030000b5040000b6040000d2040000e6040000f304000044050000480500000008000005080000a10200002d000000030000000c0000001c0000001d000000210000002800000042000000480000004a000000520000005400000055000000570000005a0000005f0000006000000064000000650000008a0000008b0000008f0000009300000099000000a0000000ad000000b1000000b9000000bb000000c5000000c8000000d0000000d6000000dd000000df000000e2000000e8000000ec000000ff0000000001000014010000150100002401000025010000380100003a010000b402000006000000120000002700000033000000b7000000e3000000e6000000c80200003900000011000000140000001e0000001f0000002000000028000000300000003100000033000000340000004000000041000000420000004300000044000000470000004a0000004b0000004c00000050000000510000005200000054000000560000006400000074000000790000007a0000007c0000008200000085000000860000008c0000008e0000008f00000092000000930000009500000096000000970000009b0000009d000000a1000000b3000000c6000000c8000000cc000000ce000000d5000000d6000000de000000e0000000e2000000fd000000080100002201000028010000de0200000d000000020000000300000029030000380300003c0300005a0300007c0400008c0400000205000003050000e00500002e0600004b060000f20200000200000004000000890500004150504152435b31303030336133645d2e444c4c0041564b4f4e5b31303030353663365d2e444c4c00434f4e455b31303030336134315d2e444c4c0045465352565b31303030333965345d2e444c4c0045494b434f52455b31303030343839325d2e444c4c0045555345525b31303030333965355d2e444c4c005045524c3539332e444c4c000000c00200005c01000000000000c002000014302830f830fc300031043108310c312c32c432c832043308335c33ac33b033b433b833bc33c033c433c833cc33f0333834443450345c346c347834843490349c34a834b434c034cc34d834e434f034fc340835143520352c353835443550355c356835743580358c359835a435b035bc35c835d435e035ec35f835043610361c362836343640364c365836643670367c3688369836a436b036bc36c836d436e036ec36f836043710371c372837343740374c375837643770377c3788379437a037ac37b837c437d037dc37e837f43700380c381838243830383c384838543860386c387838843890389c38ac38b838c438d038dc38ec38f838043910391c3928393839443950395c396c397839843990399c39a839b439c039cc39d839e439f039fc39083a143a203a2c3a3c3a483a543a603a6c3a783a843a903aa03aac3ab83ac43ad03ae03aec3af83a043bc43bc83bcc3bd03bd43bd83bdc3be03be43be83bec3bf03bf43bf83bfc3b003c043c083c0c3c103c143c183c1c3c203c243c643c683c6c3c703c743c783c7c3c803c843c883c8c3c903c943c983c9c3ca03ca43ca83cac3cb03cb43cb83cbc3cc03cc43cc83ccc3cd03cdc3ce03cec3cf03cf43cf83cfc3c003d043d083d0c3d103d143d183d1c3d203d243d283d2c3d303d343d383d3c3d403d443d483d4c3d503d543d603d643d683d6c3d703d743d783d7c3d803d843d883d8c3d903d9c3da03da43da83dac3db03db43db83dbc3dc03dc43dc83dcc3dd03dd43dd83ddc3de03de43de83dec3df83dfc3d003e043e083e0c3e103e143e183e1c3e203e243e283e343e403e443e483e543e583e5c3e603e643e683e6c3e703e743e783e7c3e803e843e883e8c3e903e943e983e9c3ea03ea43ea83eac3eb03eb43eb83ebc3ec03ecc3ed03ed43ed83edc3ee03ee43ee83eec3ef03ef43e003f0c3f103f143f203f243f303f343f383f
__APP__
  }

  # This is Symbian application resource skeleton.
  # You can create the ...\epoc32\data\z\system\apps\PerlApp\PerlApp.rsc
  # by compiling the PerlApp.cpp.
  # The following resource has been compiled using the Series 60 SDK 2.6
  # for Visual C.
  # Use symbian\hexdump.pl to create the perlrscmin.hex for this hexdump.
  if ($Variant eq 'S60') {
    $RSCHEX = <<__RSC__;
6b4a1f10000000005fde04001ca360de01b80010000400000001f0e54d0000000004f0e54d00000000000000001a00cc0800000000010005f0e54d000000000000ffffffff0000000000000000000f0500000400000000000000000000050541626f7574170000ffffffff00000000010400000000000000000000040454696d65170000ffffffff00000000020400000000000000000000030352756e170000ffffffff0000000003040000000000000000000008084f6e656c696e6572170000ffffffff000000000404000000000000000000000909436f707972696768740e0000ffffffff00000000000000000120000000000000001400cc0801006816000100000000000100000000ffffffff00ffffffff0000000000000000ffff000000000000000120000000000000002400cc0801006816000100000000000100000000ffffffff00ffffffff0000000000000000ffff000000000000004122000000000000001400cc08010069160000050000000001000000000000000001000000040007000800ff020100ffffffff00000000000000000000ffff000000000000004122000000000000001400cc08010074160007000000000054160000ffffffff000000000000ffff00000000000000000000000015001d001d0035004d00ef0026015d01a301d201d701
__RSC__
  }

  # This is Symbian application executable skeleton.
  # You can create the ...\epoc32\release\thumb\urel\foo.app
  # by compiling the PerlApp.cpp with PerlMinSample defined in PerlApp.h.
  # The following executable has been compiled using the Series 80 SDK 2.0
  # for Visual C.
  # Use symbian\hexdump.pl to create the perlappmin.hex for this hexdump.
  if ($Variant eq 'S80') {
      $APPHEX = <<__APP__;
79000010ce390010f61520108581107645504f43002000009f6ac520000000000100bb00401aaa8157e1e00003000001980e0000000000000010000000001000002000000000000001000000000000100000000007000000100f000001000000900c00007c00000000000000140f0000dc110000000000005e01000000b500f0cff902bc0847000001480068704700009c0a001000b5011c024800f075fc01bc00470000bc0a001030b585b00490002100f0e6fa6846049900f0e8fa684600f013f9011c049c9e256d006019016004980022002300f0daf9a0256d0065190020286000f0dbf9012100f0def905b030bc01bc0047f0b5071c0e1c1b4878611b48b8611b4838609e2464003d192968002910d0786800f0c0fa2968002905d008688268081c032100f081f99e246400391900200860a02464003d192868002803d000f028fc00202860796a002905d008688268081c032100f069f9381c311c00f0a1faf0bc01bc0047480c00107c0c0010d00a001084b010b595b01790189119921a9301200021002200f046fc041c14a901a800f005fc002808d10090201c17a90222002300f03efc00f000fc00f004fc15b010bc08bc04b018470000f0b5474680b4324ca544071c8846022952d100f06ffa011c0a687ea8126a00f027f98026f6006e44301c00f025fa2949301c7eaa002300f025fac425ed006d44281c00f027fa244c6c440021224868440160201c042100f023fa301c00f026fa011c201c2a1c00f027fa002824d1301c00f01cfa011c8420000168448022520000f0c2fb8521090169446846fc22520000f0c0fb84200001684400680f49694409680f4a6a4412680e4b6b441b68fff783ff381c00f024fa00204446002c00d10120094b9d4408bc9846f0bc02bc0847b4f5ffffa00a0010480a000044080000480800004c0800004c0a000000b50120fff7f2fe01bc004700b5081cfff7f6ff01bc004710b5021c80204000814203d1101c00f0f5f905e09e24640010190068fff7eaff10bc01bc0047000010b500f007f8041c00f074fb201c10bc02bc084730b5051c2c2000f071fb041c002c03d000f092fb06482060201c00f06dfb201c291c00f007f8201c30bc02bc084700003c0b001030b5041c0d1c00f0bdf8201c291c00f0bff82068016a201c00f06ef830bc01bc0047000000b5034a026000f0b7f801bc004700003c0b001030b584b0041c00f0b3f8051c6846211c00f0b4f82868b8300268281c694600f051f804b030bc01bc0047000030b5051c242000f025fb041c002c04d0291c00f08ff903482060201c30bc02bc08470000b00b001010b5a220400000f011fb041c002c0cd000f082f9074860610748a06107482060201c3430802100f00dfb201c10bc02bc08470000480c00107c0c0010d00a001010b58b20800000f003fb041c002c03d000f068f902482060201c10bc02bc08470c0c0010002070470047704708477047104770471847704720477047284770473047704738477047404770474847704750477047584770476047704770477047014b1b681847c046900c0010014b1b681847c046980c0010014b1b681847c0469c0c0010014b1b681847c046940c001040b4024e3668b44640bc6047a40c0010014b1b681847c046100d0010014b1b681847c046280d0010014b1b681847c046b40c0010014b1b681847c046080d0010014b1b681847c046180d0010014b1b681847c046140d0010014b1b681847c046f00c0010014b1b681847c046e40c0010014b1b681847c046dc0c0010014b1b681847c046000d0010014b1b681847c046fc0c0010014b1b681847c046ac0c0010014b1b681847c046a00c0010014b1b681847c046ec0c0010014b1b681847c046240d0010014b1b681847c046040d0010014b1b681847c046e00c0010014b1b681847c046bc0c0010014b1b681847c046d40c0010014b1b681847c046c80c0010014b1b681847c046c40c0010014b1b681847c046b80c0010014b1b681847c0460c0d0010014b1b681847c046e80c0010014b1b681847c046b00c0010014b1b681847c046a80c0010014b1b681847c046f40c0010014b1b681847c046d80c0010014b1b681847c046c00c0010014b1b681847c046cc0c0010014b1b681847c046f80c0010014b1b681847c046d00c0010014b1b681847c0461c0d0010014b1b681847c046200d0010014b1b681847c046400d001040b4024e3668b44640bc6047380d0010014b1b681847c0463c0d0010014b1b681847c0462c0d0010014b1b681847c046340d0010014b1b681847c046300d0010014b1b681847c046540e0010014b1b681847c0466c0d0010014b1b681847c046e80d0010014b1b681847c046300e0010014b1b681847c0465c0d0010014b1b681847c0468c0d0010014b1b681847c046340e0010014b1b681847c0463c0e0010014b1b681847c046380e0010014b1b681847c046480e0010014b1b681847c046500e0010014b1b681847c046f40d0010014b1b681847c046fc0d0010014b1b681847c046440e0010014b1b681847c046b40d0010014b1b681847c046980d0010014b1b681847c046a80d0010014b1b681847c046e40d0010014b1b681847c046d00d0010014b1b681847c046780d001040b4024e3668b44640bc6047a00d0010014b1b681847c046ac0d0010014b1b681847c046240e0010014b1b681847c046000e0010014b1b681847c046040e0010014b1b681847c046d80d0010014b1b681847c046740d0010014b1b681847c046d40d0010014b1b681847c046c80d0010014b1b681847c046640d0010014b1b681847c046f00d0010014b1b681847c046940d0010014b1b681847c046600d0010014b1b681847c046080e0010014b1b681847c046c00d0010014b1b681847c0467c0d0010014b1b681847c046880d0010014b1b681847c046dc0d0010014b1b681847c046140e0010014b1b681847c0461c0e0010014b1b681847c0460c0e0010014b1b681847c046900d0010014b1b681847c046bc0d0010014b1b681847c046b80d0010014b1b681847c046ec0d0010014b1b681847c046f80d001040b4024e3668b44640bc6047cc0d0010014b1b681847c046200e0010014b1b681847c0464c0e001040b4024e3668b44640bc6047a40d0010014b1b681847c046e00d001040b4024e3668b44640bc6047b00d0010014b1b681847c046180e0010014b1b681847c046700d0010014b1b681847c0469c0d0010014b1b681847c046680d001040b4024e3668b44640bc6047100e0010014b1b681847c046840d0010014b1b681847c046800d0010014b1b681847c046c40d0010014b1b681847c046400e0010014b1b681847c0462c0e0010014b1b681847c046280e0010014b1b681847c046600e0010014b1b681847c046800e0010014b1b681847c046700e0010014b1b681847c046740e0010014b1b681847c046640e0010014b1b681847c046780e0010014b1b681847c046580e0010014b1b681847c046680e0010014b1b681847c0465c0e0010014b1b681847c0466c0e0010014b1b681847c0467c0e0010014b1b681847c046840e0010014b1b681847c046880e001040b4024e3668b44640bc60478c0e0010014b1b681847c046540d0010014b1b681847c046500d0010014b1b681847c0464c0d0010014b1b681847c046480d0010014b1b681847c046440d0010014b1b681847c046580d00107047000000b5fff77bff01bc0047000000b5fff76fff01bc0047000010b581b0039c14380094fff725ff01b010bc01bc0047000000b51438fff716ff01bc004700b51438fff71eff01bc004700b51838fff702ff02bc0847ffffffff00000000ffffffff000000009c0a0010bc0a0010480c00107c0c0010d00a0010a00a00103c0b00103c0b0010b00b0010480c00107c0c0010d00a00100c0c0010f61520100a000000640065006600610075006c0074002e0070006c0000000000070000005000650072006c004d0069006e000000000000000000000079000010710600107d06001089060010950600106505001071050010a10600107d050010ad060010b906001089050010950500102d000010c50600104101001045020010d1060010dd060010e9060010f506001005070010110700101d070010290700100000000000000000d902001075040010810400108d04001099040010a5040010b1040010bd040010c9040010c5090010d5040010d1090010e1040010dd090010e9090010ed040010f904001005050010110500101d0500102905001035050010410500104d050010ed020010f5090010590500100000000000000000050a0010a1070010ad070010ed030010b9070010c5070010d1070010dd070010e9070010010a0010f507001001080010f9030010050400100d08001019080010250800104103001031080010410800104d0800100000000000000000110a001035070010410700100d0000104d07001059070010e103001065070010710700107d070010890700109507001019030010ecffffff00000000350a0010910800109d080010a9080010b5080010c5080010d10800101d0a0010dd080010410a0010e9080010e8ffffff000000004d0a0010a1050010ad05001003000000060000001b00000047000000030000000c0000001c0000001d0000002100000028000000420000004a0000005200000054000000550000005a0000006000000064000000650000008a0000008b0000008f0000009300000099000000a0000000b1000000bb000000c5000000c8000000d0000000d6000000dd000000df000000e2000000e8000000ff000000000100001401000015010000120000002700000033000000b7000000e3000000e6000000260100005601000065010000800200000a040000af04000011000000140000001e0000001f00000020000000300000003100000033000000340000004000000041000000420000004300000044000000470000004a0000004b0000004e0000005000000051000000520000005400000055000000560000006400000074000000790000007a0000007b0000007c0000007d0000007f0000008200000083000000860000008c0000008e0000008f0000009000000092000000930000009500000096000000970000009b0000009d000000a1000000b3000000c8000000cc000000ce000000d5000000d6000000d9000000db000000de000000e0000000e2000000e5000000fb000000fd000000fe0000002f010000020000000300000029030000380300003c0300005a0300007c0400008c0400000205000003050000e00500002e06000004000000890500000000000081030000c80200003c0200000400000003000000060000001b000000470000005102000023000000030000000c0000001c0000001d0000002100000028000000420000004a0000005200000054000000550000005a0000006000000064000000650000008a0000008b0000008f0000009300000099000000a0000000b1000000bb000000c5000000c8000000d0000000d6000000dd000000df000000e2000000e8000000ff0000000001000014010000150100006402000006000000120000002700000033000000b7000000e3000000e60000007802000006000000260100005601000065010000800200000a040000af0400008f0200003f00000011000000140000001e0000001f00000020000000300000003100000033000000340000004000000041000000420000004300000044000000470000004a0000004b0000004e0000005000000051000000520000005400000055000000560000006400000074000000790000007a0000007b0000007c0000007d0000007f0000008200000083000000860000008c0000008e0000008f0000009000000092000000930000009500000096000000970000009b0000009d000000a1000000b3000000c8000000cc000000ce000000d5000000d6000000d9000000db000000de000000e0000000e2000000e5000000fb000000fd000000fe0000002f010000a50200000c000000020000000300000029030000380300003c0300005a0300007c0400008c0400000205000003050000e00500002e060000b90200000200000004000000890500004150504152435b31303030336133645d2e444c4c00434f4e455b31303030336134315d2e444c4c0045465352565b31303030333965345d2e444c4c0045494b434f43544c5b31303030343839655d2e444c4c0045494b434f52455b31303030343839325d2e444c4c0045555345525b31303030333965355d2e444c4c005045524c3539332e444c4c0000000004020000fe000000000000000402000014302830ec30f030f4301432b032e8323c33743378337c33a033e833f43300340c341c342834343440344c345834643470347c3488349434a034ac34b834c434d034dc34e834f43400350c351835243530353c354835543560356c357835843590359c35a835b435c035d035dc35e835f43500360c361836243630363c364836543660366c367836843690369c36a836b436c036cc36d836e436f03600370c371837243730373c374837543760376c377837843790379c37a837b437c037cc37d837e437f037fc370838143820382c383c38483854386438703880388c389838a438b038c038cc38d838e438f038fc380839143920392c393839443950395c396839743980398c399839a439b439c039cc39d839e439f039fc39683a6c3a703a743a783a7c3a803a843a883a8c3a903a943a983ad83adc3ae03ae43ae83aec3af03af43af83afc3a003b043b083b0c3b103b143b183b1c3b203b243b283b2c3b303b343b383b443b483b4c3b503b543b583b5c3b603b643b683b6c3b703b743b783b7c3b803b843b883b8c3b903b943b983b9c3ba03ba43ba83bac3bb83bbc3bc03bc43bc83bcc3bd03bd43bd83bdc3be03be43be83bec3bf03bf43bf83bfc3b003c043c083c143c183c1c3c203c243c283c2c3c303c343c383c3c3c403c443c503c543c583c5c3c603c643c683c6c3c703c743c783c843c883c8c3c__APP__
  }

  # This is Symbian application resource skeleton.
  # You can create the ...\epoc32\data\z\system\apps\PerlApp\PerlApp.rsc
  # by compiling the PerlApp.cpp.
  # The following resource has been compiled using the Series 80 SDK 2.0
  # for Visual C.
  # Use symbian\hexdump.pl to create the perlrscmin.hex for this hexdump.
  if ($Variant eq 'S80') {
    $RSCHEX = <<__RSC__;
6b4a1f10000000005fde04001ca360de01b800380400000001f0e54d0000000005f0e54d000000000000000004f0e54d000000000010010000005000000000000400000204030352756e0900ffffffff00030408084f6e656c696e65720900ffffffff000504050541626f75740900ffffffff0000010404457869740500ffffffff0007010006f0e54d07074f7074696f6e73110000000000ffffffff0000000000000000000f0500000400000000000000000000050541626f7574170000ffffffff00000000010400000000000000000000040454696d65170000ffffffff00000000020400000000000000000000030352756e170000ffffffff0000000003040000000000000000000008084f6e656c696e6572170000ffffffff000000000404000000000000000000000909436f707972696768740e0000ffffffff000000000000000014001c001c0034008200a5004701__RSC__
  }
}
