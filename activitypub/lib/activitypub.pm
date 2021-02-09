package ActivityPub;
use Moo;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Digest::SHA qw(sha256_base64);
use HTTP::Date;
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use POSIX qw(strftime);

has 'agent'   => (is => 'lazy');
has 'scheme'  => (is => 'ro', default => sub { 'https' });
has 'privkey' => (is => 'ro', required => 1);

sub _build_agent {
    my $ua     = new LWP::UserAgent;
    my $agent  = "MyAgent/0.1 " . $ua->agent;
    $ua;
}

sub date_http {
    HTTP::Date::time2str(time);
}

sub date_iso {
    strftime("%Y-%m-%dT%H:%M:%SZ",gmtime(time));
}

sub sign {
    my ($self, $keyId, $inbox, $host, $date, $digest) = @_;

    my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key($self->privkey);

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
    my ($self, $host, $inbox, $person, $body) = @_;

    my $date      = $self->date_http;
    my $digest    = $self->digest($body);
    my $signature = $self->sign("$person#main-key",$inbox,$host,$date,$digest);
    my $agent     = $self->agent;
    my $scheme    = $self->scheme;

    my $req = HTTP::Request->new( 'POST', "$scheme://$host$inbox" );
    $req->header('Host'      , $host);
    $req->header('Date'      , $date);
    $req->header('Digest'    , $digest);
    $req->header('Signature' , $signature);
    $req->header('Accept',   'application/activity+json');
    $req->content($body);

    my $res = $agent->request( $req );

    $res;
}

sub get_activity_json {
    my ($self, $url) = @_;

    my $agent = $self->agent;
    my $req = HTTP::Request->new( 'GET', $url );
    $req->header('Accept',   'application/activity+json');

    my $res = $agent->request( $req );

    return unless $res->code('200');
    return unless $res->header('Content-Type') =~ /json/;

    my $json = decode_json($res->decoded_content);

    return $json;
}

sub verify {
    my ($self, $inbox ,$rheaders) = @_;

    my $signature_str = $rheaders->header('Signature');

    return unless $signature_str;

    my $signature_header = {};

    for (split(/\s*,\s*/, $signature_str)) {
        my ($name,$value) = split(/\s*=\s*/,$_,2);
        $value =~ s{^"|"$}{}mg;
        $signature_header->{$name} = $value;
    }

    my $key_id    = $signature_header->{'keyId'};
    my $headers   = $signature_header->{'headers'};
    my $signature = decode_base64(
        $signature_header->{'signature'}
    );

    return unless $key_id && $headers && $signature;

    my $actor = $self->get_activity_json($key_id);
    my $publicKeyPem = $actor->{'publicKey'}->{'publicKeyPem'};

    return unless $publicKeyPem;

    my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($publicKeyPem);

    my @comparison;

    for my $signed_header_name (split(/\s+/,$headers)) {
        if ($signed_header_name eq '(request-target)') {
            push @comparison , "(request-target): post $inbox";
        }
        elsif (defined(my $h = $rheaders->header(ucfirst($signed_header_name)))) {
            push @comparison , "$signed_header_name: $h";
        }
        else {
            # no such header
        }
    }

    my $comparison_string = join("\n", @comparison);

    $rsa_pub->use_sha256_hash();

    my $res = $rsa_pub->verify($comparison_string, $signature);

    return $res;

    # Missing (or security suggestions)
    # - check for the existence of a Digest header
    # - check if the Date header is not to far in the past (against relay attacks)
    # - check if the attribution and the actor are the same in the request and body
}

1;
