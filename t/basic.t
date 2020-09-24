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

my $watch = Watch.new: $tmpdir, { say 'callback!' };
my $file = $tmpdir.add: 'test.file';
my $filewriter = Proc::Async.new: « touch $file »;

react {
	whenever $watch.ready {
		say "writing file to $file";
		whenever $filewriter.start {
			say 'file written: ' ~ ((.exitcode == 0) ?? 'SUCCESS' !! 'FAILURE');
			$watch.stop;
		}
	}
	whenever $watch.start {
		say 'watch exited: ' ~ (.success ?? 'SUCCESS' !! 'FAILURE');
		done;
	}
}

done-testing;

