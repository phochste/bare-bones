package appserver;
use Dancer ':syntax';
use Path::Tiny;
use Catmandu;
use Catmandu::Sane;

our $VERSION = '0.1';
our $BASE_DOMAIN      = Catmandu->config->{base_domain};
our $MYSELF_PREF_NAME = Catmandu->config->{myself_pref_name};
our $MYSELF           = Catmandu->config->{myself};
our $PRIVATE_PEM      = Catmandu->config->{keys}->{private};
our $PUBLIC_PEM       = Catmandu->config->{keys}->{public};
our $PAGE_SIZE        = Catmandu->config->{page_size};

sub followers {
    Catmandu->store("followers")->bag;
}

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
        publicKey           => {
            id           => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME#main-key" ,
            owner        => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME" ,
            publicKeyPem => $pubkey
        }
    }
};

# Store all inbox requests...
post '/actor/:name/inbox' => sub {
    my $actor = param('name');

    # We only know MYSELF
    unless ($actor && $actor eq $MYSELF_PREF_NAME) {
        status 'not_found';
        return 'No such user';
    }

    my $body    = request->body;
    my $ipaddr  = request->remote_address;
    my $headers = request->headers->as_string;
    my $time    = time;

    path("data/$ipaddr-$time")->spew_utf8(
      to_json({
        "body"     => $body ,
        "ipaddr"   => $ipaddr ,
        "headers"  => $headers
      }, {allow_blessed => 1})
    );

    status 'accepted';

    return "";
};

# Show a list of followers...
get '/actor/:name/followers' => sub {
    my $actor = param('name');
    my $page  = params->{page};

    # We only know MYSELF
    unless ($actor && $actor eq $MYSELF_PREF_NAME) {
        status 'not_found';
        return 'No such user';
    }

    my $count = followers->count;

    my $response = {
       "\@context"   => "https://www.w3.org/ns/activitystreams",
       "totalItems"  => $count,
       "id"          => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/followers",
       "type"        => "OrderedCollection",
    };

    if ($page =~ /^\d+/ && $page > 0) {
        my $items   = [];

        followers->slice($page - 1 , $PAGE_SIZE)->each(sub {
            push @$items , $_[0]->{_id};
        });

        $response->{"id"}          .= "?page=$page";
        $response->{"type"}         = "OrderedCollectionPage";
        $response->{"orderedItems"} = $items;
        $response->{"partOf"}       = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/followers";

        if ($page * $PAGE_SIZE < $count ) {
            $response->{"next"} = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/followers?page=" . ($page+1);
        }
    }
    else {
        $response->{"type"}  = "OrderedCollection";
    }

    if ($count) {
        $response->{"first"} = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME?page=1";
    }

    # Return an ActivityStream document listing the followers
    content_type 'application/activity+json';

    return to_json $response;
};

true;
