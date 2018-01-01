#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
use common;

# drop a collection, reset counter

my $database='test';
my $coll='pcat';

# open user collection, get user information
my $client = MongoDB->connect();
my $db = $client->get_database( $database );
my $objects = $db->get_collection( $coll );
my $cnt = $db->get_collection( 'counters' );
$objects->drop();
my $c = $cnt->find_one_and_update( {'_id' => $coll}, {'seq' => 1});


