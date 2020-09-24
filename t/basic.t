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

my $watch = Watch.new: $tmpdir;

$watch.on-create = -> $path, $basename { say "created  {$path.IO.add: $basename}" };
$watch.on-delete = -> $path, $basename { say "deleted  {$path.IO.add: $basename}" };
$watch.on-modify = -> $path, $basename { say "modified {$path.IO.add: $basename}" };

react {
	once whenever $watch.ready {
		my $file = $tmpdir.add: 'test.file';
		once whenever Proc::Async.new(« touch $file »).start {
			once whenever $watch.ready {
				$file = $tmpdir.add: 'other.file';
				once whenever Proc::Async.new(« touch $file »).start {
					once whenever $watch.ready {
						once whenever Proc::Async.new(« rm $file »).start {
							$watch.stop;
						}
					}
				}
			}
		}
	}
	whenever $watch.start {
		say 'watch exited';
		done;
	}
}

done-testing;

