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

use Thread qw(async);
use Thread::Semaphore;

my $sem = Thread::Semaphore->new(0);

$nthreads = 4;

for (my $i = 0; $i < $nthreads; $i++) {
    async {
     	my $tid = Thread->self->tid;
	print "thread $tid started...\n";
	$sem->down;
	print "thread $tid finishing\n";
    };
}

print "main: started $nthreads threads\n";
sleep 2;

my @list = Thread->list;
printf "main: Thread->list returned %d threads\n", scalar(@list);

foreach my $t (@list) {
    print "inspecting thread $t...\n";
    print "...deref is $$t\n";
    print "...flags = ", $t->flags, "\n";
    print "...tid = ", $t->tid, "\n";
}
print "main thread telling workers to finish off...\n";
$sem->up($nthreads);
