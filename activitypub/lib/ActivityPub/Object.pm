package ActivityPub::Object;
use Moo;
use Catmandu;
use Catmandu::Sane;
use Data::UUID;
use JSON;

our $PUBLIC = "https://www.w3.org/ns/activitystreams#Public";

has 'activity' => (is => 'ro' , required => 1);
has 'base'     => (is => 'ro' , requires => 1);

sub gen_id {
    my ($self) = @_;
    my $gen  = Data::UUID->new;
    my $id   = $gen->create_str();
    my $type = lcfirst($self->type);
    $self->base . "/$type/$id";
}

sub type {
    my ($self) = @_;
    substr(ref($self),length('ActivityPub::'));
}

sub body {
    my $self    = shift;
    return $self->{_body} unless @_;
    my  (%opts) = @_;

    my $id          = $self->gen_id;
    my $type        = $self->type;
    my $date_str    = $self->activity->date_iso;

    my $body  = {
        "\@context" => "https://www.w3.org/ns/activitystreams",
        "id"           => "$id",
        "type"         => "$type",
        "published"    => "$date_str",
    };

    for my $prop (keys %opts) {
        my $value = $opts{$prop};

        if (ref($value)) {
            $body->{$prop} = $value->{_body};
        }
        else {
            $body->{$prop} = $value;
        }
    }

    $self->{_body} = $body;

    $self;
}

sub as_json {
    my ($self) = @_;
    JSON::encode_json($self->{_body});
}

1;
