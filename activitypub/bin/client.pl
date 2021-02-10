#!/usr/bin/env perl

use lib qw(./lib);
use ActivityPub;
use Path::Tiny;
use Getopt::Long;
use Catmandu;
use Catmandu::Sane;
use Data::Dumper;

# ---options----
my $verbose     = 0;
my $host        = 'scholar.social';
my $base        = 'https://cubanbar.hochstenbach.net';
my $actor       = 'fidel';
my $key_file    = 'keys/private.pem';
# ---end options----

my $person      = "$base/actor/$actor";

my $activity    = ActivityPub->new(
    privkey => path($key_file)->slurp ,
    person  => $person
);


GetOptions(
    "key|k=s"   => \$key_file ,
    "host|h=s"  => \$host ,
    "base|b=s"  => \$base ,
    "actor|a=s" => \$actor ,
    "v"         => \$verbose ,
);

my $action  = shift;

usage() unless $action;

if (0) {}
elsif ($action eq 'reply') {
    do_reply(@ARGV);
}
elsif ($action eq 'follow') {
    do_follow(@ARGV);
}

sub do_follow {
    my ($id) = @_;

    usage() unless ($id);

    my $follow = $activity->follow->body(
          actor  => $person ,
          object => $id
    );

    print $follow->as_json;

    exit (0);
}

sub do_reply {
    my ($replyId, $content) = @_;

    usage() unless ($replyId && $content);

    my $note   = $activity->note->body(
          attributedTo => $person ,
          inReplyTo    => $replyId ,
          to           => $ActivityPub::Object::PUBLIC ,
          content      => $content
    );

    my $reply  = $activity->create->body(
          $activity ,
          $person ,
          id      => $note->body->{id} . '/activity' ,
          actor   => $person ,
          object  => $note
    );

    my $res    = $activity->send(
          $host ,
          "/inbox" ,
          $person ,
          $reply
    );

    if ($res->code eq '202') {
        printf STDERR "Succes : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
    }
    else {
        printf STDERR "Failed : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
    }
}

sub status {
    my ($body) = @_;

    my $bag = Catmandu->store('status')->bag;
    $body->{'_id'} = $body->{'@id'};
    $bag->add($body);
}

sub usage {
    print STDERR <<EOF;
usage: [-v] [--host|h=host] [--actor|a=actor] {action}

actions:

    follow id
    reply id text

EOF

    exit(1);
}
