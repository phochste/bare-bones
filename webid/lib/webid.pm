package webid;

use Dancer ':syntax';
use Attean;

our $MYSELF_PREF_NAME = 'fidel';
our $MYSELF_FULL_NAME = 'Fidel';

get '/profile/:name' => sub {
    my $actor = param('name');

    # We only know MYSELF
    unless ($actor && $actor eq $MYSELF_PREF_NAME) {
        status 'not_found';
        return 'No such user';
    }

    my $parser      = Attean->get_parser('JSONLD')->new();
    my $profile     = uri_for("/profile/$actor")->as_string;
    my $image       = uri_for("/image/myself.jpg")->as_string;

    my $jsonld = to_json({
        '@context' => {
            'foaf'  => 'http://xmlns.com/foaf/0.1/'
        },
        '@graph' => [
          {
            '@id'                => $profile ,
            '@type'              => 'foaf:PersonalProfileDocument',
            'foaf:maker'         => "$profile#me",
            'foaf:primaryTopic'  => "$profile#me",
          } ,
          {
            '@id'        => "$profile#me",
            '@type'      => 'foaf:Person',
            'foaf:name'  => $MYSELF_FULL_NAME ,
            'foaf:image' => $image ,
          }
        ]
    });

    my $accept = request->header('Accept') // '*/*';


    if ($accept =~ /turtle/) {
        my $serializer  = Attean->get_serializer('Turtle')->new();
        content_type 'text/turtle';

        return $serializer->serialize_iter_to_bytes(
            $parser->parse_iter_from_bytes($jsonld)
        );
    }
    elsif ($accept =~ /rdf\+xml/) {
        my $serializer  = Attean->get_serializer('RDFXML')->new();
        content_type 'text/turtle';

        return $serializer->serialize_iter_to_bytes(
            $parser->parse_iter_from_bytes($jsonld)
        );
    }
    elsif ($accept =~ /json/) {
        content_type 'application/json+ld';

        return $jsonld;
    }
    else {
        return "Hello :)";
    }
};

true;
