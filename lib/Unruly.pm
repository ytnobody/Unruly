package Unruly;
use 5.008005;
use strict;
use warnings;
use parent 'Yancha::Client';
use WWW::Mechanize;
use URI;
use JSON;

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
    $self->token($token);
    return $self->token;
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
    my ($self, $text) = @_;
    my $post_url = $self->_path('/api/post');
    $self->_mech->post($post_url, {token => $self->token, text => $text});
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
    $self->connect;
    $self->{socket}->emit('token login', $self->token);
    $self->SUPER::run($subref);
}

1;
__END__

=encoding utf-8

=head1 NAME

Unruly - It's new $module

=head1 SYNOPSIS

    use Unruly;

=head1 DESCRIPTION

Unruly is ...

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut

