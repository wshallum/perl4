#!/usr/bin/perl -wT

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use strict;
use Config;
use Test::More;
my %modules;

%modules = (
   # ModuleName  => q| code to check that it was loaded |,
    'Cwd'        => q| ::is( ref Cwd->can('fastcwd'),'CODE' ) |,         # 5.7 ?
    'File::Glob' => q| ::is( ref File::Glob->can('doglob'),'CODE' ) |,   # 5.6
    'SDBM_File'  => q| ::is( ref SDBM_File->can('TIEHASH'), 'CODE' ) |,  # 5.0
    'Socket'     => q| ::is( ref Socket->can('inet_aton'),'CODE' ) |,    # 5.0
    'Time::HiRes'=> q| ::is( ref Time::HiRes->can('usleep'),'CODE' ) |,  # 5.7.3
);

plan tests => 27 + keys(%modules) * 2;


# Try to load the module
use_ok( 'DynaLoader' );


# Check functions
can_ok( 'DynaLoader' => 'bootstrap'               ); # defined in Perl section
can_ok( 'DynaLoader' => 'dl_error'                ); # defined in XS section
can_ok( 'DynaLoader' => 'dl_find_symbol'          ); # defined in XS section
can_ok( 'DynaLoader' => 'dl_install_xsub'         ); # defined in XS section
can_ok( 'DynaLoader' => 'dl_load_file'            ); # defined in XS section
can_ok( 'DynaLoader' => 'dl_load_flags'           ); # defined in Perl section
can_ok( 'DynaLoader' => 'dl_undef_symbols'        ); # defined in XS section
SKIP: {
    skip "unloading unsupported on $^O", 1 if ($^O eq 'VMS' || $^O eq 'darwin');
    can_ok( 'DynaLoader' => 'dl_unload_file'          ); # defined in XS section
}

TODO: {
local $TODO = "Test::More::can_ok() seems to have trouble dealing with AutoLoaded functions";
can_ok( 'DynaLoader' => 'dl_expandspec'           ); # defined in AutoLoaded section
can_ok( 'DynaLoader' => 'dl_findfile'             ); # defined in AutoLoaded section
can_ok( 'DynaLoader' => 'dl_find_symbol_anywhere' ); # defined in AutoLoaded section
}


# Check error messages
# .. for bootstrap()
eval { DynaLoader::bootstrap() };
like( $@, q{/^Usage: DynaLoader::bootstrap\(module\)/},
        "calling DynaLoader::bootstrap() with no argument" );

eval { package egg_bacon_sausage_and_spam; DynaLoader::bootstrap("egg_bacon_sausage_and_spam") };
like( $@, q{/^Can't locate loadable object for module egg_bacon_sausage_and_spam/},
        "calling DynaLoader::bootstrap() with a package without binary object" );

# .. for dl_load_file()
eval { DynaLoader::dl_load_file() };
like( $@, q{/^Usage: DynaLoader::dl_load_file\(filename, flags=0\)/},
        "calling DynaLoader::dl_load_file() with no argument" );

eval { no warnings 'uninitialized'; DynaLoader::dl_load_file(undef) };
is( $@, '', "calling DynaLoader::dl_load_file() with undefined argument" );     # is this expected ?

my ($dlhandle, $dlerr);
eval { $dlhandle = DynaLoader::dl_load_file("egg_bacon_sausage_and_spam") };
$dlerr = DynaLoader::dl_error();
SKIP: {
    skip "dl_load_file() does not attempt to load file on VMS (and thus does not fail) when \@dl_require_symbols is empty", 1 if $^O eq 'VMS';
    ok( !$dlhandle, "calling DynaLoader::dl_load_file() without an existing library should fail" );
}
ok( defined $dlerr, "dl_error() returning an error message: '$dlerr'" );

# Checking for any particular error messages or numeric codes
# is very unportable, please do not try to do that.  A failing
# dl_load_file() is not even guaranteed to set the $! or the $^E.

# ... dl_findfile()
SKIP: {
    my @files = ();
    eval { @files = DynaLoader::dl_findfile("c") };
    is( $@, '', "calling dl_findfile()" );
    # Some platforms are known to not have a "libc"
    # (not at least by that name) that the dl_findfile()
    # could find.
    skip "dl_findfile test not appropriate on $^O", 1
	if $^O =~ /(win32|vms)/i;
    # Play safe and only try this test if this system
    # looks pretty much Unix-like.
    skip "dl_findfile test not appropriate on $^O", 1
	unless -d '/usr' && -f '/bin/ls';
    cmp_ok( scalar @files, '>=', 1, "array should contain one result result or more: libc => (@files)" );
}

# Now try to load well known XS modules
my $extensions = $Config{'extensions'};
$extensions =~ s|/|::|g;

for my $module (sort keys %modules) {
    SKIP: {
        skip "$module not available", 1 if $extensions !~ /\b$module\b/;
        eval "use $module";
        is( $@, '', "loading $module" );
    }
}

# checking internal consistency
is( scalar @DynaLoader::dl_librefs, scalar keys %modules, "checking number of items in \@dl_librefs" );
is( scalar @DynaLoader::dl_modules, scalar keys %modules, "checking number of items in \@dl_modules" );

my @loaded_modules = @DynaLoader::dl_modules;
for my $libref (reverse @DynaLoader::dl_librefs) {
  SKIP: {
    skip "unloading unsupported on $^O", 2 if ($^O eq 'VMS' || $^O eq 'darwin');
    my $module = pop @loaded_modules;
    my $r = eval { DynaLoader::dl_unload_file($libref) };
    is( $@, '', "calling dl_unload_file() for $module" );
    is( $r,  1, " - unload was successful" );
  }
}

