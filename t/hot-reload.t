use v6;

use Test;
use HotReload;

my @units = [
];

plan @units.elems;

ok False, .name for @units;

my $uid = sprintf '%d%d%d%d', (0..9).pick: 4;
my $tmpdir = $*TMPDIR.add("hot-reload-test-$uid");
mkdir $tmpdir;
END { run « rm -r $tmpdir »  if $tmpdir.defined }

my $hr = HotReload.new: $tmpdir, « echo 'hello world' », :out, :err;
my $out = '';
my $err = '';
react {
	once whenever $hr.ready {
		my $file = $tmpdir.add: 'test.file';
		say "creating file $file";
		once whenever Proc::Async.new(« touch $file »).start {
			 whenever $hr.ready {
				whenever $hr.stop { done }
			}
		}
	}
	whenever $hr.stdout { $out ~= $_ }
	whenever $hr.stderr { $err ~= $_ }
	whenever $hr.start  { done }
}

is $out, q:to/EOS/, 'hot reload emits "hello world" twice';
hello world
hello world
EOS

is $err, '', 'hot reload emits nothing to stderr';

done-testing;

