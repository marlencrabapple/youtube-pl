package YouTubePL;

use YouTubePL;
use Plack::MIME;
use Plack::Builder;

my $app = YouTubePL->new;

Plack::MIME->add_type('.ytdl' => 'application/octet-stream');

builder {
  enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
    "Plack::Middleware::ReverseProxy";
  enable "Plack::Middleware::Static",
    path => qr{^/static/}, root => '';
  $app->run
}
