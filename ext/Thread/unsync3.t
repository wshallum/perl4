BEGIN {
    eval { require Config; import Config };
    if ($@) {
	print "1..0 # Skip: no Config\n";
	exit(0);
    }
    if ($Config{extensions} !~ /\bThread\b/) {
	print "1..0 # Skip: no use5005threads\n";
	exit(0);
    }
}

use Thread;

$| = 1;

srand($$^$^T);

sub whoami {
    my $thread = shift;
    print $thread;
}

sub uppercase {
    my $count = 100;
    while ($count--) {
	my $i = int(rand(1000));
	1 while $i--;
	print "A";
	$i = int(rand(1000));
	1 while $i--;
	whoami("B");
    }
}
	
sub lowercase {
    my $count = 100;
    while ($count--) {
	my $i = int(rand(1000));
	1 while $i--;
	print "x";
	$i = int(rand(1000));
	1 while $i--;
	whoami("y");
    }
}
	
sub numbers {
    my $count = 100;
    while ($count--) {
	my $i = int(rand(1000));
	1 while $i--;
	print 1;
	$i = int(rand(1000));
	1 while $i--;
	whoami(2);
    }
}
	
new Thread \&numbers;
new Thread \&uppercase;
new Thread \&lowercase;
