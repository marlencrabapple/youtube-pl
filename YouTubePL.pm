package YouTubePL;

use strict;

use lib './you-the-real-mvc';
use Framework;

use JSON;
use Try::Tiny;
#use AnyEvent;
#use AnyEvent::Run;
use Data::Dumper;

sub build {
  before_dispatch(sub {
    my ($request, $params, $pathstr, $patharr) = @_;

    if(@{$patharr}[0] eq 'video') {
      return if(!$$params{url} && !$$params{id});

      if($$params{url}) {
        ($$params{id}) = ($$params{url} =~ /([A-Za-z0-9_-]{11})/);
        redirect("/video/$$params{id}") if $$params{id};
      }

      make_error("Invalid Video ID/URL.") unless valid_video($$params{id})
    }
  });

  get('/', sub {
    res(template('embed')->(
      title => "YouTube Video Downloader"
    ))
  });

  prefix('video', sub {
    get('/', sub {
      redirect('/')
    });

    get('/:id', sub {
      my ($params) = @_;
      my ($videoinfo, @videolinks, @audiolinks);

      try {
        $videoinfo = from_json(`youtube-dl -j https://youtu.be/$$params{id}`);
      }
      catch {
        make_error("Something went wrong :(")
      };

      $$videoinfo{description} =~ clean_string(decode_string($$videoinfo{description}));
      $$videoinfo{description} =~ s/\n/<br>/g;

      foreach my $format (@{$$videoinfo{formats}}) {
        if($$format{format} =~ /audio only/) {
          push @audiolinks, $format unless $$format{format} =~ /nondash/i
            || $$format{ext} eq 'webm';
        }
        else {
          push @videolinks, $format unless $$format{format} =~ /dash/i
        }
      }

      res(template('embed')->(
        title => "Download $$videoinfo{fulltitle} - $$videoinfo{uploader}",
        videoid => $$params{id},
        videoinfo => $videoinfo,
        videolinks => \@videolinks,
        audiolinks => \@audiolinks
      ))
    });

    get('/:id/info', sub {
      my ($params) = @_;

      res(from_json(`youtube-dl -j https://youtu.be/$$params{id}`));
    });

    get('/:id/download', sub {
      download_video(shift)
    });

    get('/:id/download/:itag', sub {
      download_video(shift)
    });
  })
}

sub valid_video {
  my ($str) = @_;
  my $urlre = url_regexp();

  # i don't think its possible to escape urls for use as path vars so we'll
  # probably never use this
  if($str =~ /$urlre/ig) {
    return 0;

    ($str) = ($str =~ /([A-Za-z0-9_-]{11})/);
    return 1 if $str;
  }

  return 1 if $str =~ /[A-Za-z0-9_-]{11}/;
  return 0;
}

sub valid_itag {
  my ($itag) = @_;

  return 1 if $itag =~ /[0-9a-z]+/;
  return 0;
}

sub download_video {
  my ($params) = @_;
  my @itagargs = ($$params{itag} && valid_itag($$params{itag}))
    ? ('-f', $$params{itag}) : ();

  my $time = time();

  system 'youtube-dl', "https://youtu.be/$$params{id}", @itagargs, '-o',
    "./static/dl/$$params{name}.ytdl";

  #redirect("/static/dl/$$params{name}.ytdl")
  res({ url => "/static/dl/$$params{name}.ytdl", fn => $$params{name},
    itag => $$params{itag} })
}

1;
