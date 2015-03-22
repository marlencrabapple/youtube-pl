package YouTubePL;

use lib './you-the-real-mvc';
use Framework;

sub build {
  get('/', sub {
    res('Hello, world!')
  });

  get('/:name', sub {
    res('Hello, ' . shift->{name} . '!')
  });
}

1;
