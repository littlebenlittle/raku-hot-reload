
use Watcher;

unit class HotReload does Watcher;

use Watch;

has @.cmd;
has Bool $!capture-stdout;
has Bool $!capture-stderr;

has $!stdout = Supplier.new;
has $!stderr = Supplier.new;
method stdout (-->Supply) { return $!stdout.Supply }
method stderr (-->Supply) { return $!stderr.Supply }

has $!exit = Supplier.new;

method new($dir, @cmd, :$out = False, :$err = False) {
	self.bless: :$dir, :@cmd, :capture-stdout($out), :capture-stderr($err);
}

method BUILD(:$!dir, :@!cmd, :$!capture-stdout, :$!capture-stderr) { }

method start { Promise.start: { react {
	my $STOP    = False;
	my $watch   = Watch.new: $.dir;
	my $signals = signal(SIGTERM).merge(signal(SIGINT)).merge(signal(SIGHUP));
	my $next    = Supplier.new;
	my $stop    = Supplier.new;
	whenever $watch.ready {  }
	whenever $watch.events {
		note "{.type}  {.path}";
		$stop.emit: Any;
	}
	whenever $next.Supply {
		my $proc = Proc::Async.new: @.cmd, :out, :err;
		whenever $stop.Supply {
			note 'sending SIGHUP to process';
			$proc.kill: SIGHUP
		}
		whenever $proc.stdout { $!stdout.emit: $_ if $!capture-stdout }
		whenever $proc.stderr { $!stderr.emit: $_ if $!capture-stderr }
		whenever $proc.ready  { $!ready.emit: Any }
		whenever $signals     { $proc.kill: $_ }
		whenever $proc.start {
			if $STOP {
				$!exit.emit: Any;
				done;
			}
			note 'starting next process';
			$next.emit: Any;
		}
	}
	whenever $.done {
		$STOP = True;
		$watch.stop;
	}
	whenever $watch.start {
		note 'AA';
		$stop.emit: Any
	}
	$next.emit: Any;
}}}

method stop { Promise.start: {
	$!done.emit: Any;
	await $!exit.Supply;
} }

