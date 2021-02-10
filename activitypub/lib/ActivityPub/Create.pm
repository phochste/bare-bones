package ActivityPub::Create;
use Moo;
use Data::UUID;
use JSON;

extends 'ActivityPub::Object';

sub body {
    my $self    = shift;
    return $self->{_body} unless @_;
    my  (%opts) = @_;

    die "need actor and object" unless $opts{actor} && $opts{object};
    $self->SUPER::body(%opts);
}

1;
