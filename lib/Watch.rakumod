
unit class Watch:ver<0.0.0>:auth<github:littlebenlittle>;

has $.dir;
has $!procs = Supplier.new; #= supply for subprocesses spawned by this Watch
has $.ready = Supplier.new; #= sends Any when Watche is established
has $!done  = Supplier.new; #= send Any to stop this watch
has $.finished  = Supplier.new;
has &.on-create is rw;
has &.on-modify is rw;
has &.on-delete is rw;

method new(IO() $dir) {
	self.bless(:$dir);
}

submethod BUILD(:$!dir) {}

method start {
	return Promise.start: {
		react {
			my @cmd = « inotifywait -e MODIFY,DELETE,CREATE -r $.dir »;
			my $STOP = False;
			whenever $!procs.Supply -> Proc::Async:D $proc {
				whenever $proc.stdout.lines {
					if $_ ~~ /
						$<path>=('/'+ %% [[<.alnum> | '-' | '_']+])
						<.ws>
						$<event>=('CREATE'|'MODIFY'|'DELETE')
						<.ws>
						$<basename>=<-[\v]>+
					/ {
						my &fn;
						given $/<event>.Str {
							when 'CREATE' { &fn = &.on-create }
							when 'MODIFY' { &fn = &.on-modify }
							when 'DELETE' { &fn = &.on-delete }
						}
						fn($/<path>.Str, $/<basename>.Str)
					} else {
						# .say;
					}
				}
				whenever $proc.stderr.lines.merge {
					if $_ ~~ / 'Watches established.' / {
						$.ready.emit: Any;
					} else {
						# .note
					}
				}
				whenever $proc.start {
					done if $STOP;
					$!procs.emit: Proc::Async.new(@cmd, :out, :err);
				}
				once whenever signal(SIGTERM).merge: signal(SIGINT) {
					$STOP = True;
					$proc.kill: $_;
				}
				once whenever $!done.Supply {
					$STOP = True;
					$proc.kill: SIGTERM;
				}
			}
			say "starting new watch on $.dir...";
			$!procs.emit: Proc::Async.new(@cmd, :out, :err);
		}
	};
}

method stop {
	return Promise.start: {
		react {
			whenever $.finished.Supply { done }
			$!done.emit: Any;
		}
	};
}

