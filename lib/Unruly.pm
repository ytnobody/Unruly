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

our $VERSION = "0.06";

sub new {
    my ($class, %opts) = @_;
    $opts{ping_interval} ||= 20;
    $opts{connection_lifetime} ||= 30;
    $opts{when_lost_connection} ||= sub { die 'Lost connection' }; 
    $class->SUPER::new(%opts);
}

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
    $self->{__login} = {
        method => 'twitter_login', 
        params => [$user, $password, $login_point],
    };
    $self->connect;
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
    $self->{__login} = {
        method => 'login', 
        params => [$user, $opts],
    };
    $self->connect;
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

sub connect {
    my $self = shift;

    $self->{__cv} = AnyEvent->condvar;
    $self->{__cv}->begin;

    $self->{__pong_time} = time;

    $self->{__ping_timer} ||= AnyEvent->timer(
        after    => $self->{ping_interval}, 
        interval => $self->{ping_interval}, 
        cb       => sub { $self->ping },
    );

    $self->{__life_timer} ||= AnyEvent->timer(
        after    => 1,
        interval => 1,
        cb => sub {
            if (time - $self->{__pong_time} >= $self->{connection_lifetime}) {
                $self->{when_lost_connection}->($self);
            }
        }
    );

    $self->SUPER::connect or croak('could not connect');

    $self->socket->on('token login' => sub {
        my ($client, $socket) = @_;
        my $status = $socket->{status};
        carp('login failure') unless $status eq 'ok';
        $self->set_tags( $self->_tags, sub { $self->{__cv}->end } );
    });

    $self->socket->on('pong' => sub {
        my $received = $_[1];
        if ($self->token eq $received) {
            $self->{__pong_time} = time;
        };
    });

    $self->socket->emit('token login', $self->token);

    1;
}

sub myname {
    my $self = shift;
    $self->{__user};
}

sub disconnect {
    my $self = shift;
    $self->socket->close;
    $self->{socket} = undef;
    warn 'Connection was closed';
}

sub ping {
    my $self = shift;
    $self->socket->emit('ping', $self->token);
}

sub join {
    my ($self, $channel) = @_;
    $self->{tags}{$channel} = 1;
    $self->set_tags( $self->_tags, sub { $self->{__cv}->end } );
}

sub leave {
    my ($self, $channel) = @_;
    delete $self->{tags}{$channel};
    $self->set_tags( $self->_tags, sub { $self->{__cv}->end } );
}

1;
__END__

=encoding utf-8

=head1 NAME

Unruly - Yancha client with twitter auth

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

=head2 url 

Yancha server URL (string)

=head2 tags 

Listening tags (hashref)

=head2 ping_interval 

Interval in seconds for sending ping (integer, default is 20)

=head2 connection_lifetime

Lifetime in seconds of connection without pong (integer, default is 30);

=head2 when_lost_connection 

Callback subroutine that executes when connection was lost (coderef, default is sub { die 'Lost connection'})

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

=head2 join($tag)

Join to specified tag.

=head2 leave($tag)

Leave from specified tag.

=head1 SETUP SCRIPT

This distribution includes unruly_setup.pl - a setup script for develop a original bot.

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut

