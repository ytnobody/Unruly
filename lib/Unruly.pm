package Unruly;
use 5.008005;
use strict;
use warnings;
use parent 'Yancha::Client';
use AnyEvent;
use WWW::Mechanize;
use URI;
use JSON;
use Carp;

our $VERSION = "0.01";

sub twitter_login {
    my ($self, $user, $password, $login_point) = @_;
    return $self->token if $self->token;

    $login_point ||= '/login/twitter/start';

    my $login_url  = $self->_path($login_point);
    my $mech       = $self->_mech;
    my $domain     = $login_url->host;

    $mech->get($login_url);
    $mech->submit_form(
        form_id => 'oauth_form',
        fields  => {
            'session[username_or_email]' => $user,
            'session[password]'          => $password,
        },
    );
    my ($jump_to) = $mech->content =~ m{<meta http-equiv="refresh" content="0;url=(.*?)">};
    $mech->get($jump_to);
    my $token = $mech->cookie_jar->{COOKIES}{$domain}{'/'}{yancha_auto_login_token}[1];
    croak('failure to login') unless $token;
    $self->token($token);
    $self->{__user} = $user;
    return $self->token;
}

sub login {
    my ($self, $user, $opts) = @_;
    my $login_point   = $opts->{login_point} || 'login';
    my $profile_image = $opts->{image}       || undef;
    my $token_only    = $opts->{token_only}  || 0;
    my $rtn = $self->SUPER::login($self->{url}, $login_point, {nick => $user, profile_image_url => $profile_image, token_only => $token_only});
    croak('failure to login') unless $self->token;
    $self->{__user} = $user;
    return $rtn;
}

sub _tags {
    my $self = shift;
    keys %{$self->{tags}} if $self->{tags};
}

sub _path {
    my ($self, $path) = @_;
    my $uri = URI->new($self->{url});
    $uri->path($path);
    return $uri;
}

sub _mech {
    my $self = shift;
    $self->{_mech} ||= WWW::Mechanize->new(
        agent      => join('/', __PACKAGE__, $VERSION),
        cookie_jar => {},
    );
    return $self->{_mech};
}

sub post {
    my ($self, $text, @tags) = @_;
    $text = join(' ', $text, map { '#'.$_ } @tags) if @tags;
    $self->socket->emit('user message' => $text);
}

sub hidden_post {
    my ($self, $text, @tags) = @_;
    push @tags, 'NOREC';
    $self->post($text, @tags);
}

sub users {
    my $self = shift;
    my $users_url = $self->_path('/api/user');
    $self->_mech->get($users_url);
    return JSON->new->utf8(1)->decode($self->_mech->res->content);
}

sub search {
    my ($self, %opts) = @_;
    $opts{order} ||= '-created_at_ms';
    my $search_url = $self->_path('/api/search');
    $search_url->query_form(%opts);
    $self->_mech->get($search_url);
    return JSON->new->utf8(1)->decode($self->_mech->res->content);
}

sub run {
    my ( $self, $subref ) = @_;

    my @tags = $self->_tags;
    my $cv = AnyEvent->condvar;
    $cv->begin;

    $self->connect or croak('could not connect');

    $self->socket->on('token login' => sub {
        my ($client, $socket) = @_;
        my $status = $socket->{status};
        carp('login failure') unless $status eq 'ok';
        $self->set_tags( @tags, sub { $cv->end } );
    });

    $self->socket->emit('token login', $self->token);

    $self->SUPER::run($subref);
}

sub myname {
    my $self = shift;
    $self->{__user};
}

1;
__END__

=encoding utf-8

=head1 NAME

Unruly - It's new $module

=head1 SYNOPSIS

    use Unruly;
    use AnyEvent;
    use utf8;

    my $cv = AnyEvent->condvar;

    my $c = Unruly->new(url => 'http://yancha.hachiojipm.org', tags => {PUBLIC => 1});
    $c->login('waiwai');

    $c->run(sub {
        my ($client, $socket) = @_;
        $socket->on('user message' => sub {
            my $message = $_[1];
            unless($message->{nickname} eq 'waiwai') {
                my @tags = @{$message->{tags}};
                if ($message->{text} =~ /ワイワイ/) {
                    $c->post('ワイワイ', @tags);
                }
            }
        });
    });

    $cv->wait;


=head1 DESCRIPTION

Unruly is a client lib for Yancha L<http://yancha.hachiojipm.org>.

=head1 OPTIONS

=head2 url (string)

=head2 tags (hashref)

=head1 METHOD

=head2 login($nickname, $opts)

    $unruly->login('yourbot', {image => 'http://example.com/prof.png'}); 

Login to yancha. You may specify following options

=over 4

=item token_only => $bool (1 = stealth-mode, 0 = normal, default is 0)

=item image => $image_url

=back 

=head2 twitter_login($twitter_id, $twitter_password)

    $unruly->twitter_login('your_twitter_id', 'seCreT');

Login to yancha with twitter account

=head2 post($message, @tags)

    $unruly->post('Hello, world!', qw/PUBLIC PRIVATE/);

Post a message to yancha.

=head2 hidden_post($message, @tags)

Post a "NOREC" message to yancha.

=head2 run($coderef);

    $unruly->run(sub {
        my ($client, $socket) = @_;
        $socket->on('event name' => sub { ... });
    });

Start event-loop.

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut

