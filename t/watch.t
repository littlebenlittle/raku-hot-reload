use v6;

use Test;
use Watch;

class Unit {
}

my @units = [
];

plan @units.elems;

ok False, .name for @units;

my $uid = sprintf '%d%d%d%d', (0..9).pick: 4;
my $tmpdir = $*TMPDIR.add("watch-test-$uid");
mkdir $tmpdir;
END { run « rm -r $tmpdir »  if $tmpdir.defined }

my $watch = Watch.new: $tmpdir;

react {
	once whenever $watch.ready {
		my $file = $tmpdir.add: 'test.file';
		once whenever Proc::Async.new(« touch $file »).start {
			once whenever $watch.ready {
				$file = $tmpdir.add: 'other.file';
				once whenever Proc::Async.new(« touch $file »).start {
					once whenever $watch.ready {
						once whenever Proc::Async.new(« rm $file »).start {
							await $watch.stop;
							say 'all done!';
						}
					}
				}
			}
		}
	}
	whenever $watch.create { say "CREATE  {.path}" }
	whenever $watch.modify { say "MODIFY  {.path}" }
	whenever $watch.delete { say "DELETE  {.path}" }
	whenever $watch.start  { done }
}

done-testing;

