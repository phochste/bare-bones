#!/usr/bin/env perl

use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Path::Tiny;
use HTTP::Date;
use HTTP::Request;
use MIME::Base64;
use Getopt::Long;
use Data::Dumper;
use LWP::UserAgent;
use Digest::SHA qw(sha256_base64);
use POSIX qw(strftime);

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

my $version     = sprintf "%d-%d" , time , int(rand(999));
my $date_http   = HTTP::Date::time2str(time);
my $date_str    = strftime("%Y-%m-%dT%H:%M:%SZ",gmtime(time-10));

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
		"attributedTo": "$base/actor/$actor",
		"inReplyTo": "$replyId",
		"content": "$content",
		"to": "https://www.w3.org/ns/activitystreams#Public"
	}
}
EOF

send_message($body);

sub send_message {
    my $body        = shift;

    Crypt::OpenSSL::RSA->import_random_seed();

    my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key(
        path($key_file)->slurp
    );

    $rsa_priv->use_sha256_hash();

    my $ua = new LWP::UserAgent;

    my $agent         = "MyAgent/0.1 " . $ua->agent;
    my $digest        = "sha-256=" . sha256_base64($body) . '=';
    my $signed_string = "(request-target): post /inbox\nhost: $host\ndate: $date_http\ndigest: $digest";
    my $signature     = $rsa_priv->sign($signed_string);
    my $signature_64  = encode_base64($signature,'');
    my $header        = "keyId=\"$base/actor/$actor#main-key\",algoritn=\"rsa-sha256\",headers=\"(request-target) host date digest\",signature=\"$signature_64\"";

    $ua->agent($agent);

    my $req = HTTP::Request->new( 'POST', "https://$host/inbox" );
    $req->header('Host' , $host);
    $req->header('Date' , $date_http);
    $req->header('Digest', $digest);
    $req->header('Signature' , $header);
    $req->header('Accept', 'application/activity+json');
    $req->content($body);

    my $res = $ua->request( $req );

    print STDERR Dumper($res) if $verbose;

    if ($res->code eq '202') {
        printf STDERR "Succes : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
    }
    else {
        printf STDERR "Failed : %s : %s : %s\n" , $res->code , $res->message , $res->decoded_content;
    }
}
