package ActivityPub::Reply;
use Moo;
use Data::UUID;
use JSON;

sub  body {
    my ($self, $activity, $base, $actor, $replyId, $content) = @_;

    my $date_str  = $activity->date_iso;

    my $gen       = Data::UUID->new;
    my $object_id = $gen->create_str();
    my $note_id   = $gen->create_str();

    my $body  = {
        "\@context" => "https://www.w3.org/ns/activitystreams",
        "id"        => "$base/$object_id",
        "type"      => "Create",
        "actor"     => "$actor",
        "object"    => {
            "id"           => "$base/$note_id",
            "type"         => "Note",
            "published"    => "$date_str",
            "attributedTo" => "$actor",
            "inReplyTo"    => "$replyId",
            "content"      => "$content",
            "to"           => "https://www.w3.org/ns/activitystreams#Public"
        }
    };

    JSON::encode_json($body);
}

1;
