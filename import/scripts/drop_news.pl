#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
use common;

# drop a collection, reset counter

my $database='test';

my $db = MongoDB->connect()->get_database($database);

$db->get_collection( 'news' )->drop();
$db->get_collection( 'comm' )->drop();

my $cnt = $db->get_collection( 'counters' );
$cnt->find_one_and_update( {'_id' => 'news'}, {'seq' => 1});
$cnt->find_one_and_update( {'_id' => 'comm'}, {'seq' => 1});


