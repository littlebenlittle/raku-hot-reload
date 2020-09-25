
use Watcher;

unit class Watch does Watcher;

has $!procs = Supplier.new; #= supply for subprocesses spawned by this Watch
has $!close = Supplier.new; #= emits when watch is closed

method new(IO() $dir) {
	self.bless(:$dir);
}

submethod BUILD(:$!dir) {}

class Event {
	enum Type <CREATE MODIFY DELETE>;
	has IO::Path $.path;
	has Type     $.type;
}

method start { Promise.start: { react {
	my @cmd = « inotifywait -e MODIFY,DELETE,CREATE -r $.dir »;
	my $STOP = False;
	whenever $!procs.Supply -> Proc::Async:D $proc {
		whenever $proc.stdout.lines {
			if $_ ~~ /
				$<dir>=('/'+ %% [[<.alnum> | '-' | '_']+])
				<.ws>
				$<event>=('CREATE'|'MODIFY'|'DELETE')
				<.ws>
				$<basename>=<-[\v]>+
			/ {
				my $path = $/<dir>.IO.add: $/<basename>.Str;
				my $type;
				given $/<event>.Str {
					when 'CREATE' { $type = Event::Type::CREATE }
					when 'MODIFY' { $type = Event::Type::MODIFY }
					when 'DELETE' { $type = Event::Type::DELETE }
				}
				$!events.emit: Event.new: :$path, :$type;
			} else {
				# .say;
			}
		}
		whenever $proc.stderr.lines {
			if $_ ~~ / 'Watches established.' / {
				$!ready.emit: Any;
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
			note "watch cancelled by $_";
			$proc.kill: $_;
		}
		once whenever $!done.Supply {
			$STOP = True;
			note 'watch cancelled';
			$proc.kill: SIGTERM;
		}
	}
	say "starting new watch on $.dir...";
	$!procs.emit: Proc::Async.new(@cmd, :out, :err);
}}}

method stop { Promise.start: { $!done.emit: Any; } }

method create { $.events.grep: {.type == Event::Type::CREATE }}
method modify { $.events.grep: {.type == Event::Type::MODIFY }}
method delete { $.events.grep: {.type == Event::Type::DELETE }}
