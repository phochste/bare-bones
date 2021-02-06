package activitypub;
use Dancer ':syntax';
use Path::Tiny;

our $VERSION = '0.1';
our $BASE_DOMAIN      = "cubanbar.hochstenbach.net";
our $MYSELF_PREF_NAME = "fidel";
our $MYSELF           = "acct:$MYSELF_PREF_NAME\@$BASE_DOMAIN";
our $PRIVATE_PEM      = "keys/private.pem";
our $PUBLIC_PEM       = "keys/public.pem";

# Webfinger is how we are going to learn where we find information about
# MYSELF@my-eexample.com
get '/.well-known/webfinger' => sub {
    my $resource = params->{resource};

    # We need a resource
    unless ($resource) {
        status 'not_found';
        return 'Need a resource';
    }

    # We only know MYSELF...
    unless ($resource eq $MYSELF) {
        status 'not_found';
        return 'No such user';
    }

    # Static response for MYSELF
    # Content type for webfinger is application/jrd+json
    content_type 'application/jrd+json';
    return to_json {
        subject => $MYSELF ,
        links   => [{
            rel   => "self" ,
            type  => "application/activity+json" ,
            href  => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME"
        }]
    };
};

# Actor is an ActivityPub message to learn more about MYSELF (name,inbox,outbox...)
get '/actor/:name' => sub {
    my $actor = param('name');

    # We only know MYSELF
    unless ($actor && $actor eq $MYSELF_PREF_NAME) {
        status 'not_found';
        return 'No such user';
    }

    my $pubkey = path($PUBLIC_PEM)->slurp;
    $pubkey    =~ s{\n}{\\n}mg;

    # Return an ActivityStream document about MYSELF
    content_type 'application/activity+json';

    return to_json {
        '@context'          => [
              "https://www.w3.org/ns/activitystreams",
		          "https://w3id.org/security/v1"
        ] ,
        id                  => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME" ,
        type                => "Person",
        preferredUsername   => $MYSELF_PREF_NAME ,
        inbox               => "https://$BASE_DOMAIN/inbox/$MYSELF_PREF_NAME" ,
        pubkey              => {
            id           => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME#main-key" ,
            owner        => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME" ,
            publicKeyPem => $pubkey
        }
    }
};

true;
