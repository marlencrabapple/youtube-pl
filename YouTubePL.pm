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

our $procs = {};
our $dbh = Framework::Database->new([ option('sql_source'), option('sql_user'),
  option('sql_pass'), { AutoCommit => 1 } ], 1);

mkdir './cache' unless -e './cache';
mkdir './static/dl' unless -e './static/dl';

sub build {
  init_video_table($dbh) unless $dbh->table_exists('videos');

  before_dispatch(sub {
    my ($request, $params, $pathstr, $patharr) = @_;

    $dbh->wakeup();

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
    res(template('index')->(
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
      my $videoinfo = get_videoinfo($$params{id}, $$params{refresh});

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
  my ($sth, $filename, $time, $videoinfo, $ext, $cv, @ytdlargs);
  my ($id, $vitag, $aitag) = ($$params{id}, split('\+', $$params{itag}));
  $time = time();

  $sth = $dbh->prepare("SELECT no,filename FROM videos WHERE id=? AND formatid=?")
    or make_error(string('s_sqlerror'));
  $sth->execute($id, $vitag) or make_error(string('s_sqlerror'));

  if(my $row = $sth->fetchrow_hashref) {
    $filename = $$row{filename};

    $sth = $dbh->prepare("UPDATE videos SET lastaccessed=? WHERE no=?")
      or make_error(string('s_sqlerror'));
    $sth->execute($$row{no}, $time) or make_error(string('s_sqlerror'));
  }
  else {
    @ytdlargs = ($$params{itag} && valid_itag($$params{itag}))
      ? ('-f', $$params{itag}) : ();
    push @ytdlargs, ('--prefer-ffmpeg', '--ffmpeg-location', option('ffmpeg_path'))
      if option('enable_dash');

    $filename = $time . sprintf("%03d", int(rand(1000)));

    $sth = $dbh->prepare("INSERT INTO videos VALUES(null,?,?,?,?,null,null)")
      or make_error(string('s_sqlerror'));
    $sth->execute($id, $filename, $vitag, time())
      or make_error(string('s_sqlerror'));

    $videoinfo = get_videoinfo($id); # just make sure it exists
    push @ytdlargs, ('--load-info', "./cache/$$params{id}");

    if($vitag && $aitag) {
      foreach my $format (@{$$videoinfo{formats}}) {
        print "$vitag $$format{format_id}\n";

        if($$format{format_id} eq $vitag) {
          $ext = $$format{ext};
          last;
        }
      }

      # hopefully this is a good enough catchall...
      $ext = 'mp4' unless $ext;
    }
    else {
      $ext = 'ytdl'
    }

    $cv = AnyEvent->condvar;

    $$procs{$id} = AnyEvent::Run->new(
      cmd => [ 'youtube-dl', '-v', "https://youtu.be/$id", @ytdlargs, '-o',
        "./static/dl/$filename.$ext", $filename ],
      on_read => sub {
        my ($hdl) = @_;
        #my $line = $hdl->{rbuf};
        #print "$line\n";
        $cv->send;
      },
      on_error => sub {
        my ($hdl, $fatal, $msg) = @_;
        #print "$fatal: $msg ($!)\n";
        #rename "./static/dl/$filename.$ext", "./static/dl/$filename" if(lc($msg) eq 'broken pipe');
        rename "./static/dl/$filename.$ext", "./static/dl/$filename";
        $cv->send;
      },
      on_eof => sub {
        print "is it done?\n"; # doesn't work?
      }
    );
  }

  res({ url => "/static/dl/$filename", fn => $filename,
    itag => $$params{itag} })
}

sub download_status {
  my ($params) = @_;

  if(-e "./static/dl/$$params{fn}") {
    my $sth = $dbh->prepare("UPDATE videos SET complete=?,lastaccessed=? WHERE filename=?")
      or make_error(string('s_sqlerror'));
    $sth->execute(1, 1, $$params{fn}) or make_error(string('s_sqlerror'));

    res({ finished => 1 })
  }
  else {
    res({ finished => 0 })
  }

  # res({ finished => 1 })
  #   unless(!-e "./static/dl/$$params{fn}") || (`lsof './static/dl/$$params{fn}'`);
  #
  # res({ finished => 0 })
}

sub get_videoinfo {
  my ($id, $refresh, $success_cb, $expired_cb, $new_cb) = @_;
  my $videoinfo;

  if((-e "./cache/$id") && (!$refresh)) {
    open my $fh, '<', "./cache/$id" or make_error($!);
    while(my $row = <$fh>) {
      $videoinfo .= $row
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

#
# Database Stuff
#

sub init_table {
  my ($dbh, $table, $columns) = @_;
  my ($sth, @column_arr);

  foreach my $column (@{$columns}) {
    my $column_str = "`$$column{name}` " . ($$column{auto_increment} ?
      $dbh->get_autoincrement() : sub {
        if($$column{type}) {
          if($$column{type} eq 'ip') {
            return 'TEXT' if option('sql_source') =~ /^DBI:SQLite/i;
            return 'VARBINARY(16)' if option('sql_source') =~ /^DBI:MySQL/i;

            # bytea(16) might be better if it actually works...
            # No idea if this can detect an IP in binary either.
            return 'inet' if option('sql_source') =~ /^DBI:Pg/i;
            return 'TEXT';
          }

          return $$column{type}
        }

        return 'TEXT';
      }->());

    push @column_arr, $column_str;
  }

  $sth = $dbh->prepare("CREATE TABLE $table (" . join(',', @column_arr) . ")")
    or $dbh->error();
  $sth->execute();
}

sub init_video_table {
  init_table($dbh, 'videos', [
    { name => 'no', auto_increment => 1 },
    { name => 'id' },
    { name => 'filename' },
    { name => 'formatid', type=> 'TINYINT' },
    { name => 'saved', type => 'INTEGER' },
    { name => 'lastaccessed', type => 'INTEGER' },
    { name => 'complete', type => 'TINYINT' }
  ])
}

1;
