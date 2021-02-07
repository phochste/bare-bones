package ActivityPub;
use Moo;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Digest::SHA qw(sha256_base64);
use HTTP::Date;
use LWP::UserAgent;
use MIME::Base64;
use POSIX qw(strftime);

has 'agent' => (is => 'lazy');

sub _build_agent {
    my $ua     = new LWP::UserAgent;
    my $agent  = "MyAgent/0.1 " . $ua->agent;
    $agent;
}

sub date_http {
    HTTP::Date::time2str(time);
}

sub date_iso {
    strftime("%Y-%m-%dT%H:%M:%SZ",gmtime(time));
}

sub sign {
    my ($self, $keyId, $inbox, $host, $date, $digest, $privkey) = @_;

    my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key($privkey);

    $rsa_priv->use_sha256_hash();

    my $signed_string = "(request-target): post $inbox\nhost: $host\ndate: $date\ndigest: $digest";
    my $signature     = encode_base64($rsa_priv->sign($signed_string),'');
    my $header        = "keyId=\"$keyId\",algoritm=\"rsa-sha256\"," .
                        "headers=\"(request-target) host date digest\"," .
                        "signature=\"$signature\"";

    $header;
}

sub digest {
    my ($self, $body) = @_;

    my $digest = "sha-256=" . sha256_base64($body) . '=';

    $digest;
}

sub send {
    my ($self, $host, $inbox, $date, $digest, $signature, $body) = @_;

    my $agent = $self->agent;

    my $req = HTTP::Request->new( 'POST', "https://$host$inbox" );
    $req->header('Host'      , $host);
    $req->header('Date'      , $date);
    $req->header('Digest'    , $digest);
    $req->header('Signature' , $signature);
    $req->header('Accept',   'application/activity+json');
    $req->content($body);

    my $res = $agent->request( $req );

    $res;
}

1;
