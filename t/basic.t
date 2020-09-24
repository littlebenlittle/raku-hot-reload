use v6;

use Test;
use Watch:ver<0.0.0>:auth<github:littlebenlittle>;

class Unit {
}

my @units = [
];

plan @units.elems;

ok False, .name for @units;

my $uid = sprintf '%d%d%d%d', (0..9).pick: 4;
my $tmpdir = $*TMPDIR.add("hot-reload-test-$uid");
mkdir $tmpdir;
END { run « rm -r $tmpdir »  if $tmpdir.defined }

my $pass = False;
my $watch = Watch.new: $tmpdir, {
	$pass = True
};

react {
	#|( Create two files: Wait until the first is detected
	    by inotifywait before creating the second
	)
	once whenever $watch.ready {
		my $file = $tmpdir.add: 'test.file';
		whenever (Proc::Async.new: « touch $file »).start {
			once whenever $watch.ready {
				$file = $tmpdir.add: 'other.file';
				whenever (Proc::Async.new: « touch $file »).start {
					$watch.stop;
				}
			}
		}
	}
	whenever $watch.start {
		say 'watch exited: ' ~ (.success ?? 'SUCCESS' !! 'FAILURE');
		done;
	}
}

if $pass {
	say 'pass!'
} else {
	say 'fail!'
}

done-testing;

