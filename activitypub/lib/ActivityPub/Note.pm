package ActivityPub::Note;
use Moo;
use Data::UUID;
use JSON;

extends 'ActivityPub::Object';

sub gen_id {
    my ($self) = @_;
    my $gen  = Data::UUID->new;
    my $id   = $gen->create_str();
    my $type = lcfirst($self->type);
    $self->base . "/statuses/$id";
}

1;
