#!/usr/bin/env perl

use lib qw(./lib);
use ActivityPub;
use ActivityPub::Reply;
use Path::Tiny;
use Getopt::Long;
use Data::Dumper;

my $verbose  = 0;
my $host     = 'scholar.social';
my $base     = 'https://cubanbar.hochstenbach.net';
my $actor    = 'fidel';
my $key_file    = 'keys/private.pem';

GetOptions(
    "key|k=s"   => \$key_file ,
    "host|h=s"  => \$host ,
    "base|b=s"  => \$base ,
    "actor|a=s" => \$actor ,
    "v"         => \$verbose ,
);

my $replyId = shift;
my $content = shift;

unless ($replyId && $content) {
    print STDERR "usage: [-v] [--host|h=host] [--actor|a=actor] id text\n";
    exit(1);
}

my $activity    = ActivityPub->new(
    privkey => path($key_file)->slurp
);

my $person = "$base/actor/$actor";
my $res    = $activity->send(
      $host ,
      "/inbox" ,
      $person ,
      ActivityPub::Reply->new->body(
          $activity ,
          "$base/note",
          $person ,
          $replyId ,
          $content
      )
);

if ($res->code eq '202') {
    printf STDERR "Succes : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
}
else {
    printf STDERR "Failed : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
}
