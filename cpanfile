requires 'perl', '5.014';

requires 'App::Greple', '8';
requires 'IO::Uncompress::Unzip';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
