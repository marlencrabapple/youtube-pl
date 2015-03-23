package YouTubePL;

use YouTubePL;
use Plack::Builder;

my $app = YouTubePL->new;

builder {
  enable "Plack::Middleware::Static",
    path => qr{^/static/}, root => '';
  $app->run
}
