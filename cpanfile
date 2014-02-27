requires 'perl', '5.008001';
requires 'JSON';
requires 'PocketIO::Client::IO';
requires 'URI';
requires 'WWW::Mechanize';

### for script/unruly_setup.pl
requires 'File::Spec';
requires 'Carp';
requires 'IO::Handle';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

