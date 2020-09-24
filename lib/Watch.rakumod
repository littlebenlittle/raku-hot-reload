
unit class Watch:ver<0.0.0>:auth<github:littlebenlittle>;

has $.dir;
has &.callback;
has $.procs = Supplier.new; #= supply for subprocesses spawned by this Watch
has $.ready = Supplier.new;
has $.done  = Supplier.new;
has $.finished  = Supplier.new;
has $.events  = Supplier.new;

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
			my @cmd = « inotifywait -e MODIFY,DELETE,CREATE -r $.dir »;
			my $STOP = False;
			whenever $.procs.Supply -> Proc::Async:D $proc {
				whenever $proc.stdout.lines {
					if $_ ~~ /
						$<path>=('/'+ %% [[<.alnum> | '-' | '_']+])
						<.ws>
						$<event>=('CREATE'|'MODIFY'|'DELETE')
						<.ws>
						$<basename>=<-[\v]>+
					/ {
						say "{$/<event>.Str}: {$/<basename>.Str}";
					} else {
						say $_;
					}
				}
				whenever $proc.stderr.lines.merge {
					.note;
					if $_ ~~ / 'Watches established.' / {
						$.ready.emit: Any;
					}
				}
				whenever $proc.start {
					say "process exited {.exitcode}";
					(&.callback)();
					done if $STOP;
					$.procs.emit: Proc::Async.new(@cmd, :out, :err);
				}
				once whenever signal(SIGTERM).merge: signal(SIGINT) {
					$STOP = True;
					$proc.kill: $_;
				}
				once whenever $.done.Supply {
					$STOP = True;
					$proc.kill: SIGTERM;
				}
			}
			say "starting new watch on $.dir...";
			$.procs.emit: Proc::Async.new(@cmd, :out, :err);
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

