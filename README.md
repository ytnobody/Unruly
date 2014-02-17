# NAME

Unruly - Yancha client with twitter auth

# SYNOPSIS

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



# DESCRIPTION

Unruly is a client lib for Yancha [http://yancha.hachiojipm.org](http://yancha.hachiojipm.org).

# OPTIONS

## url 

Yancha server URL (string)

## tags 

Listening tags (hashref)

## ping\_interval 

Interval in seconds for sending ping (integer, default is 20)

## connection\_lifetime

Lifetime in seconds of connection without pong (integer, default is 30);

## when\_lost\_connection 

Callback subroutine that executes when connection was lost (coderef, default is sub { die 'Lost connection'})

# METHOD

## login($nickname, $opts)

    $unruly->login('yourbot', {image => 'http://example.com/prof.png'}); 

Login to yancha. You may specify following options

- token\_only => $bool (1 = stealth-mode, 0 = normal, default is 0)
- image => $image\_url

## twitter\_login($twitter\_id, $twitter\_password)

    $unruly->twitter_login('your_twitter_id', 'seCreT');

Login to yancha with twitter account

## post($message, @tags)

    $unruly->post('Hello, world!', qw/PUBLIC PRIVATE/);

Post a message to yancha.

## hidden\_post($message, @tags)

Post a "NOREC" message to yancha.

## run($coderef);

    $unruly->run(sub {
        my ($client, $socket) = @_;
        $socket->on('event name' => sub { ... });
    });

Start event-loop.

# LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

ytnobody <ytnobody@gmail.com>
