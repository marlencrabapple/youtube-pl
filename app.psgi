package YouTubePL;

use YouTubePL;
use Plack::MIME;
use Plack::Builder;

my $app = YouTubePL->new;

Plack::MIME->add_type('.ytdl' => 'application/octet-stream');

builder {
  enable "Plack::Middleware::Static",
    path => qr{^/static/}, root => '';
  $app->run
}
