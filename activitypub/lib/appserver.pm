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
        following           => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/following" ,
        followers           => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/followers" ,
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
get qr{/actor/(\w+)/(followers|following)} => sub {
    my ($actor,$follower_or_following) = splat;
    my $page  = params->{page};

    # We only know MYSELF
    unless ($actor && $actor eq $MYSELF_PREF_NAME) {
        status 'not_found';
        return 'No such user';
    }

    my $bag   = Catmandu->store($follower_or_following)->bag;
    my $count = $bag->count;

    my $response = {
       "\@context"   => "https://www.w3.org/ns/activitystreams",
       "totalItems"  => $count,
       "id"          => "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/$follower_or_following",
       "type"        => "OrderedCollection",
    };

    if ($page && $page =~ /^\d+/) {
        my $items   = [];

        $bag->slice($page * $PAGE_SIZE, $PAGE_SIZE)->each(sub {
            push @$items , $_[0]->{_id};
        });

        $response->{"id"}          .= "?page=$page";
        $response->{"type"}         = "OrderedCollectionPage";
        $response->{"orderedItems"} = $items;
        $response->{"partOf"}       = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/$follower_or_following";

        if (($page + 1) * $PAGE_SIZE < $count ) {
            $response->{"next"} = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/$follower_or_following?page=" . ($page+1);
        }
        else {
            # we are on the last page...
        }
    }
    else {
        $response->{"type"}  = "OrderedCollection";
        if ($count) {
            $response->{"first"} = "https://$BASE_DOMAIN/actor/$MYSELF_PREF_NAME/$follower_or_following?page=1";
        }
        else {
            # no followers...
        }
    }

    # Return an ActivityStream document listing the followers
    content_type 'application/activity+json';

    return to_json $response;
};

true;
