#!/usr/bin/env perl

use lib qw(./lib);
use ActivityPub;
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

my $activity    = ActivityPub->new;
my $privkey     = path($key_file)->slurp;
my $person      = "$base/actor/$actor";
my $version     = sprintf "%d-%d" , time , int(rand(999));
my $date_http   = $activity->date_http;
my $date_str    = $activity->date_iso;

my $body          =<<EOF;
{
	"\@context": "https://www.w3.org/ns/activitystreams",

	"id": "$base/create-hello-world-$version",
	"type": "Create",
	"actor": "$base/actor/$actor",

	"object": {
		"id": "$base/hello-world-$version",
		"type": "Note",
		"published": "$date_str",
		"attributedTo": "$person",
		"inReplyTo": "$replyId",
		"content": "$content",
		"to": "https://www.w3.org/ns/activitystreams#Public"
	}
}
EOF

my $digest    = $activity->digest($body);
my $signature = $activity->sign(
      "$person#main-key" ,
      "/inbox" ,
      $host ,
      $date_http ,
      $digest ,
      $privkey
);

my $res = $activity->send(
      $host ,
      "/inbox" ,
      $date_http ,
      $digest ,
      $signature ,
      $body
);

if ($res->code eq '202') {
    printf STDERR "Succes : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
}
else {
    printf STDERR "Failed : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
}
