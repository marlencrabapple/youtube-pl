package YouTubePL;

use strict;

use lib './you-the-real-mvc';
use Framework;

use YouTubePL::ConfigDefaults;
use YouTubePL::Config;

use JSON;
use Try::Tiny;
use AnyEvent;
use AnyEvent::Run;
use Data::Dumper;
use File::Slurp;

our $procs = {};

mkdir './cache' unless -e './cache';
mkdir './static/dl' unless -e './static/dl';

sub build {
  before_dispatch(sub {
    my ($request, $params, $pathstr, $patharr) = @_;

    #@procs = grep { $$_{finished} != 1} @procs;

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

  get('/status/:fn', sub {
    download_status(shift)
  });

  prefix('video', sub {
    get('/', sub {
      redirect('/')
    });

    get('/:id', sub {
      my ($params) = @_;
      my ($videoinfo, @videolinks, @audiolinks);

      $videoinfo = get_videoinfo($$params{id});

      #$$videoinfo{fulltitle} = encode_string($$videoinfo{fulltitle});
      $$videoinfo{description} = clean_string(decode_string($$videoinfo{description}));
      $$videoinfo{description} =~ s/\n/<br>/g;

      foreach my $format (@{$$videoinfo{formats}}) {
        if($$format{format} !~ /nondash\-/) {
          if($$format{vcodec} eq 'none') {
            push @audiolinks, $format unless $$format{format} =~ /nondash/i
              #|| $$format{ext} eq 'webm'
          }
          else {
            push @videolinks, $format if $$format{format} !~ /dash/i
              || option('enable_dash')
          }
        }
      }

      foreach my $videolink (@videolinks) {
        if($$videolink{acodec} eq 'none') {
          my $acodec = $$videolink{ext} eq 'webm' ? 'webm' : 'm4a';
          foreach my $audiolink (@audiolinks) {
            if($$audiolink{ext} eq $acodec) {
              $$videolink{format_id} .= "+$$audiolink{format_id}";
              last
            }
          }
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
      my $videoinfo;

      if((-e "./cache/$$params{id}") && (!$$params{refresh})) {
        try {
          $videoinfo = decode_json(read_file("./cache/$$params{id}", { binmode => ':utf8' }))
        }
        catch {
          unlink "./cache/$$params{id}";
          make_error("Something went wrong :(")
        };

        unlink "./cache/$$params{id}" if $$videoinfo{cached} + 3600 < time()
      }
      else {
        try {
          $videoinfo = decode_json(`youtube-dl -j https://youtu.be/$$params{id}`);
          $$videoinfo{cached} = time();
          write_file("./cache/$$params{id}", encode_json($videoinfo))
        }
        catch {
          unlink "./cache/$$params{id}";
          make_error("Something went wrong :(")
        };
      }

      res($videoinfo);
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

  return 1 if $itag =~ /^[0-9a-z]+(?:\+[0-9a-z]+)?$/;
  return 0;
}

sub download_video {
  my ($params) = @_;

  my @ytdlargs = ($$params{itag} && valid_itag($$params{itag}))
    ? ('-f', $$params{itag}) : ();
  push @ytdlargs, ('--prefer-ffmpeg', '--ffmpeg-location', option('ffmpeg_path')) if option('enable_dash');

  my $time = time();

  my $videoinfo = get_videoinfo($$params{id}); # just make sure it exists
  push @ytdlargs, ('--load-info', "./cache/$$params{id}");

  my $cv = AnyEvent->condvar;

  $$procs{$$params{id}} = AnyEvent::Run->new(
    cmd => [ 'youtube-dl', '-v', "https://youtu.be/$$params{id}", @ytdlargs, '-o',
      './static/dl/' . $$params{name}, '2>&1' ]
  );

  # read the response line
  $$procs{$$params{id}}->push_read(line => sub {
    my ($hdl, $line) = @_;
    print "got line <$line>\n";
    $cv->send;
  });

  res({ url => "/static/dl/$$params{name}", fn => $$params{name},
    itag => $$params{itag} })
}

sub download_status {
  my ($params) = @_;

  res({ finished => 1, proc_arr => Dumper($procs) })
    unless(!-e "./static/dl/$$params{fn}") || (`lsof './static/dl/$$params{fn}'`);

  res({ finished => 0, proc_arr => Dumper($procs) })
}

sub get_videoinfo {
  my ($id, $success_cb, $expired_cb, $new_cb) = @_;
  my $videoinfo;

  if(-e "./cache/$id") {
    open my $fh, '<', "./cache/$id" or make_error($!);
    while(my $row = <$fh>) {
      $videoinfo .= $row;
    }
    close $fh;

    $videoinfo = decode_json($videoinfo);

    if($$videoinfo{cached} + 3600 > time()) {
      $success_cb->($videoinfo) if ref $expired_cb eq 'CODE'
    }
    else {
      unlink "./cache/$id";
      $videoinfo = fetch_videoinfo($id);
      $$videoinfo{cached} = time();
      $expired_cb->($videoinfo) if ref $expired_cb eq 'CODE';

      open my $fh, '>', "./cache/$id" or make_error($!);
      print $fh encode_json($videoinfo);
      close $fh
    }
  }
  else {
    $videoinfo = fetch_videoinfo($id);
    $$videoinfo{cached} = time();
    $new_cb->($videoinfo) if ref $expired_cb eq 'CODE';

    open my $fh, '>', "./cache/$id" or make_error($!);
    print $fh encode_json($videoinfo);
    close $fh
  }

  return $videoinfo
}

sub fetch_videoinfo {
  my ($id) = @_;
  my ($videoinfo, $i);

  while(1) {
    try {
      $videoinfo = decode_json(`youtube-dl -j https://youtu.be/$id`)
    }
    catch {
      make_error("Something went wrong :(") if $i >= 5;
      $i++
    };

    last
  }

  return $videoinfo
}

1;
