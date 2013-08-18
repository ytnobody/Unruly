requires 'perl', '5.008001';
requires 'JSON';
requires 'PocketIO::Client::IO';
requires 'URI';
requires 'WWW::Mechanize';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

