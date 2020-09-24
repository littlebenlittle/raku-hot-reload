
unit class Watch:ver<0.0.0>:auth<github:littlebenlittle>;

has $.dir;
has &.callback;
has @.cmd = « inotifywait -e MODIFY,DELETE -r $!dir »;
has $.procs = Supplier.new; #= supply for subprocesses spawned by this Watch
has $.ready = Supplier.new;
has $.done  = Supplier.new;
has $.finished  = Supplier.new;

method new(IO() $dir, &callback) {
	self.bless(:$dir, :&callback);
}

submethod BUILD(:$!dir, :&!callback) {}

class Result {
	has Bool $.success;
}

method start {
	return Promise.start: {
		react {
			whenever $.procs.Supply -> Proc::Async:D $proc {
				whenever $proc.stderr.lines.merge: $proc.stdout.lines {
					say $_;
					if $_ ~~ / 'Watches established.' / {
						$.ready.emit: Any;
					}
				}
				whenever $proc.start {
					say "process exited {.exitcode}";
					$.finished.emit: Any;
					done;
				}
				once whenever signal(SIGTERM).merge: signal(SIGINT) {
					$proc.kill: $_;
				}
				once whenever $.done.Supply {
					$proc.kill: SIGTERM;
				}
			}
			say "starting new watch on $.dir...";
			$.procs.emit: Proc::Async.new(@.cmd, :out, :err);
		}
		Result.new( success => True );
	};
}

method stop {
	return Promise.start: {
		react {
			whenever $.finished.Supply { done }
			$.done.emit: Any;
		}
	};
}

