
unit role Watcher;

has $.dir;

has $!done   = Supplier.new;
has $!ready  = Supplier.new;
has $!events = Supplier.new;

method done   (-->Supply)  { return $!done.Supply   }
method ready  (-->Supply)  { return $!ready.Supply  }
method events (-->Supply)  { return $!events.Supply }

method start (-->Promise)  {...}
method stop  (-->Promise)  {...}

